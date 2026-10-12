import 'dart:async';
import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/snackbar_extension.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/app_feedback_service.dart';
import 'package:kortex/src/core/themes/app_motion.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/features/profile/presentation/widgets/syllabot_settings/active_download_progress_banner.dart';
import 'package:kortex/src/features/profile/presentation/widgets/syllabot_settings/syllabot_settings_section_container.dart';
import 'package:kortex/src/features/syllabot/data/client/local_llm_engine_client.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

/// Section widget for managing on-device local LLM neural weights and execution.
class OnDeviceNeuralModelsSection extends StatelessWidget {
  const OnDeviceNeuralModelsSection({
    required this.localModels,
    required this.isLoadingLocalModels,
    required this.localClient,
    required this.onRefreshModels,
    this.activeDownloadingModelId,
    super.key,
  });

  final List<LocalLlmModelInfo> localModels;
  final bool isLoadingLocalModels;
  final String? activeDownloadingModelId;
  final LocalLlmEngineClient localClient;
  final Future<void> Function() onRefreshModels;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    return SyllabotSettingsSectionContainer(
      title: 'ON-DEVICE NEURAL MODELS',
      subtitle:
          'Switch active local model, download neural weights, or delete models to free disk space (Only 1 active download allowed per device)',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Active Download Progress Lock Banner
          const ActiveDownloadProgressBanner(),

          if (isLoadingLocalModels)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: CircularProgressIndicator.adaptive(),
              ),
            )
          else
            Column(
              children: localModels.map((model) {
                final isDownloadingThisModel =
                    activeDownloadingModelId == model.id;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: model.isActive
                          ? colors.primary.withAlpha(isDark ? 35 : 18)
                          : colors.surfaceSecondary,
                      borderRadius: AppRadius.radiusCard,
                      border: Border.all(
                        color: model.isActive
                            ? colors.primary.withAlpha(isDark ? 110 : 80)
                            : colors.surfaceBorder.withAlpha(70),
                        width: model.isActive ? 1.5 : 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: colors.primary.withAlpha(25),
                                borderRadius: AppRadius.radiusBadge,
                              ),
                              child: Icon(
                                Icons.memory_rounded,
                                size: 20,
                                color: colors.primary,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          model.name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: typography.body.bold.copyWith(
                                            color: colors.textPrimary,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      if (model.isActive)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: colors.primary,
                                            borderRadius:
                                                AppRadius.radiusMicro,
                                          ),
                                          child: Text(
                                            'ACTIVE ENGINE',
                                            style: typography.caption.bold
                                                .copyWith(
                                                  color: colors.white,
                                                  fontSize: 9,
                                                  letterSpacing: 0.5,
                                                ),
                                          ),
                                        )
                                      else if (model.isDownloaded)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color:
                                                colors.success.withAlpha(30),
                                            borderRadius:
                                                AppRadius.radiusMicro,
                                            border: Border.all(
                                              color:
                                                  colors.success.withAlpha(80),
                                              width: 0.8,
                                            ),
                                          ),
                                          child: Text(
                                            'DOWNLOADED',
                                            style: typography.caption.bold
                                                .copyWith(
                                                  color: colors.success,
                                                  fontSize: 9,
                                                ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    model.description,
                                    style: typography.caption.regular.copyWith(
                                      color: colors.textSecondary,
                                      fontSize: 11.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              model.sizeLabel,
                              style: typography.caption.bold.copyWith(
                                color: colors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            if (model.isDownloaded) ...[
                              if (!model.isActive)
                                ShrinkableButton(
                                  onTap: () async {
                                    AppFeedback.selection();
                                    try {
                                      await localClient.setActiveModel(
                                        model.id,
                                      );
                                      await onRefreshModels();
                                      if (context.mounted) {
                                        context.showSnackBar(
                                          message:
                                              '${model.name} is now the active on-device neural engine!',
                                          type: SnackBarType.success,
                                        );
                                      }
                                    } on Object catch (e) {
                                      if (context.mounted) {
                                        context.showSnackBar(
                                          message:
                                              'Failed to set active model: $e',
                                          type: SnackBarType.error,
                                        );
                                      }
                                    }
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 7,
                                    ),
                                    decoration: BoxDecoration(
                                      color: colors.primary.withAlpha(25),
                                      borderRadius: AppRadius.radiusBadge,
                                      border: Border.all(
                                        color: colors.primary.withAlpha(80),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.check_circle_outline_rounded,
                                          size: 14,
                                          color: colors.primary,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Switch to Active',
                                          style: typography.caption.bold
                                              .copyWith(
                                                color: colors.primary,
                                                fontSize: 11,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              const SizedBox(width: 8),
                              ShrinkableButton(
                                onTap: () async {
                                  AppFeedback.light();
                                  final confirmed = await showDialog<bool>(
                                    context: context,
                                    builder: (dialogCtx) => AlertDialog(
                                      backgroundColor: colors.surfacePrimary,
                                      title: Text(
                                        'Delete Model Weights?',
                                        style: typography.body.bold.copyWith(
                                          color: colors.textPrimary,
                                        ),
                                      ),
                                      content: Text(
                                        'Are you sure you want to delete ${model.name} weights (${model.sizeLabel}) from local device storage?',
                                        style: typography.caption.regular
                                            .copyWith(
                                              color: colors.textSecondary,
                                            ),
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.of(
                                            dialogCtx,
                                          ).pop(false),
                                          child: const Text('Cancel'),
                                        ),
                                        TextButton(
                                          onPressed: () => Navigator.of(
                                            dialogCtx,
                                          ).pop(true),
                                          child: Text(
                                            'Delete',
                                            style: TextStyle(
                                              color: colors.error,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );

                                  if (confirmed == true) {
                                    await localClient.deleteModel(model.id);
                                    await onRefreshModels();
                                    if (context.mounted) {
                                      context.showSnackBar(
                                        message:
                                            '${model.name} weights deleted successfully.',
                                      );
                                    }
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 7,
                                  ),
                                  decoration: BoxDecoration(
                                    color: colors.error.withAlpha(20),
                                    borderRadius: AppRadius.radiusBadge,
                                    border: Border.all(
                                      color: colors.error.withAlpha(60),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.delete_outline_rounded,
                                        size: 14,
                                        color: colors.error,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Delete',
                                        style: typography.caption.bold.copyWith(
                                          color: colors.error,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ] else ...[
                              ShrinkableButton(
                                onTap: isDownloadingThisModel ||
                                        LocalLlmEngineClient
                                            .isGlobalDownloadActive
                                    ? () {
                                        AppFeedback.light();
                                        context.showSnackBar(
                                          message:
                                              'Another model download is already in progress on this device.',
                                        );
                                      }
                                    : () {
                                        AppFeedback.light();
                                        try {
                                          unawaited(
                                            localClient
                                                .downloadModel(
                                                  preset: model.preset,
                                                )
                                                .drain<void>()
                                                .catchError((Object err) {
                                                  if (context.mounted) {
                                                    context.showSnackBar(
                                                      message:
                                                          'Download failed: $err',
                                                      type: SnackBarType.error,
                                                    );
                                                  }
                                                }),
                                          );
                                        } on LocalLlmAlreadyDownloadingException catch (e) {
                                          if (context.mounted) {
                                            context.showSnackBar(
                                              message: e.message,
                                            );
                                          }
                                        }
                                      },
                                child: AnimatedContainer(
                                  duration: AppMotion.snappy,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 7.5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: LocalLlmEngineClient
                                            .isGlobalDownloadActive
                                        ? colors.surfaceSecondary
                                        : colors.primary,
                                    borderRadius: AppRadius.radiusBadge,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.download_rounded,
                                        size: 14,
                                        color: LocalLlmEngineClient
                                                .isGlobalDownloadActive
                                            ? colors.textSecondary
                                            : colors.white,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        isDownloadingThisModel
                                            ? 'Downloading...'
                                            : LocalLlmEngineClient
                                                    .isGlobalDownloadActive
                                                ? 'Download Locked'
                                                : model.hasPartialDownload
                                                    ? 'Resume (${(model.partialBytes / 1024 / 1024).toInt()} MB)'
                                                    : 'Download Model',
                                        style: typography.caption.bold.copyWith(
                                          color: LocalLlmEngineClient
                                                  .isGlobalDownloadActive
                                              ? colors.textSecondary
                                              : colors.white,
                                          fontSize: 11.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }
}
