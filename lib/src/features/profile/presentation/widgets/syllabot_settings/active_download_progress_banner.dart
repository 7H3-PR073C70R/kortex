import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/features/syllabot/data/client/local_llm_engine_client.dart';

/// Standalone isolated progress banner widget that subscribes to
/// [LocalLlmEngineClient.downloadProgressStream] without triggering
/// full parent page rebuilds during scrolling.
class ActiveDownloadProgressBanner extends HookWidget {
  const ActiveDownloadProgressBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    final activeDownloadState = useState<ModelDownloadProgressState?>(
      LocalLlmEngineClient.isGlobalDownloadActive
          ? ModelDownloadProgressState(
              modelId: LocalLlmEngineClient.activeDownloadingModelId ?? '',
              modelName:
                  LocalLlmEngineClient.activeDownloadingModelName ?? 'Model',
              progress: LocalLlmEngineClient.activeDownloadProgress,
              isDownloading: true,
            )
          : null,
    );

    useEffect(() {
      var isMounted = true;
      final sub = LocalLlmEngineClient.downloadProgressStream.listen((state) {
        if (isMounted) {
          activeDownloadState.value = state;
        }
      });
      return () {
        isMounted = false;
        unawaited(sub.cancel());
      };
    }, const []);

    final download = activeDownloadState.value;
    if (download == null) {
      return const SizedBox.shrink();
    }

    if (!download.isDownloading && download.errorMessage != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: colors.error.withAlpha(isDark ? 35 : 20),
              borderRadius: AppRadius.radiusCard,
              border: Border.all(
                color: colors.error.withAlpha(isDark ? 100 : 70),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  color: colors.error,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Download Interrupted',
                        style: typography.body.bold.copyWith(
                          color: colors.error,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        download.errorMessage!,
                        style: typography.caption.regular.copyWith(
                          color: colors.textPrimary,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      );
    }

    if (!download.isDownloading) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: colors.primary.withAlpha(isDark ? 35 : 20),
            borderRadius: AppRadius.radiusCard,
            border: Border.all(
              color: colors.primary.withAlpha(isDark ? 100 : 70),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: colors.primary.withAlpha(40),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.downloading_rounded,
                      size: 16,
                      color: colors.primary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Downloading ${download.modelName}...',
                          style: typography.body.bold.copyWith(
                            color: colors.primary,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          'Single active download lock enforced across device',
                          style: typography.caption.regular.copyWith(
                            color: colors.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${(download.progress * 100).toInt()}%',
                    style: typography.caption.bold.copyWith(
                      color: colors.primary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: AppRadius.radiusMicro,
                child: LinearProgressIndicator(
                  value: download.progress,
                  backgroundColor: colors.surfaceSecondary,
                  valueColor: AlwaysStoppedAnimation<Color>(colors.primary),
                  minHeight: 6,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}
