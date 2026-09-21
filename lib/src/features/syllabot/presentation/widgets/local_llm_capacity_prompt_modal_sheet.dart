import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kortex/src/core/extensions/snackbar_extension.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/device_capability_service.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/syllabot/data/client/local_llm_engine_client.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

/// Modal bottom sheet that audits device capabilities (storage, CPU, RAM)
/// and prompts the user before downloading local quantized LLM weights.
class LocalLlmCapacityPromptModalSheet extends StatefulWidget {
  const LocalLlmCapacityPromptModalSheet({
    this.onDownloadComplete,
    super.key,
  });

  final VoidCallback? onDownloadComplete;

  static Future<bool?> show(
    BuildContext context, {
    VoidCallback? onDownloadComplete,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.colors.transparent,
      builder: (_) => LocalLlmCapacityPromptModalSheet(
        onDownloadComplete: onDownloadComplete,
      ),
    );
  }

  @override
  State<LocalLlmCapacityPromptModalSheet> createState() =>
      _LocalLlmCapacityPromptModalSheetState();
}

class _LocalLlmCapacityPromptModalSheetState
    extends State<LocalLlmCapacityPromptModalSheet> {
  // ignore: use_late_for_private_fields_and_variables - report is null until audit completes
  DeviceCapabilityReport? _report;
  bool _isLoadingReport = true;
  bool _isDownloading = false;
  double _downloadProgress = 0;
  StreamSubscription<double>? _downloadSub;

  @override
  void initState() {
    super.initState();
    unawaited(_auditDevice());
  }

  Future<void> _auditDevice() async {
    final service = DeviceCapabilityService();
    final report = await service.auditDeviceCapacity();
    if (mounted) {
      setState(() {
        _report = report;
        _isLoadingReport = false;
      });
    }
  }

  @override
  void dispose() {
    unawaited(_downloadSub?.cancel());
    super.dispose();
  }

  void _startDownload() {
    final client = locator<LocalLlmEngineClient>();
    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.05;
    });

    _downloadSub = client.downloadModel().listen(
      (progress) {
        if (mounted) {
          setState(() {
            _downloadProgress = progress;
          });
        }
      },
      onDone: () {
        if (mounted) {
          setState(() {
            _isDownloading = false;
            _downloadProgress = 1.0;
          });
          context.showSnackBar(
            message: 'On-Device Neural Engine ready (248 MB)! Activated.',
            type: SnackBarType.success,
          );
          widget.onDownloadComplete?.call();
          Navigator.of(context).pop(true);
        }
      },
      onError: (Object error) {
        if (mounted) {
          setState(() {
            _isDownloading = false;
          });
          context.showSnackBar(
            message: 'Model download failed. Please check internet connection.',
            type: SnackBarType.error,
          );
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 28,
      ),
      decoration: BoxDecoration(
        color: isDark ? colors.surfacePrimary : colors.backgroundPrimary,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(
          color: isDark
              ? colors.surfaceBorderHighlight.withAlpha(50)
              : colors.surfaceBorder.withAlpha(120),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag Handle
          Center(
            child: Container(
              width: 38,
              height: 4.5,
              decoration: BoxDecoration(
                color: colors.textSecondary.withAlpha(80),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
          const SizedBox(height: 18),

          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: colors.primary.withAlpha(isDark ? 50 : 25),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.memory_rounded,
                  size: 24,
                  color: colors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'On-Device AI Engine',
                      style: typography.title2.bold.copyWith(
                        color: colors.textPrimary,
                        fontSize: 17,
                      ),
                    ),
                    Text(
                      'Quantized 4-bit Neural Model (248 MB)',
                      style: typography.caption.medium.copyWith(
                        color: colors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Overview description
          Text(
            'Run Syllabot reasoning locally on your device with complete offline privacy, zero data usage, and low latency.',
            style: typography.footnote.regular.copyWith(
              color: colors.textSecondary,
              fontSize: 12.5,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),

          // Device Capability Audit Box
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark
                  ? colors.surfaceSecondary.withAlpha(140)
                  : colors.surfaceSecondary.withAlpha(90),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: colors.surfaceBorder.withAlpha(isDark ? 50 : 100),
              ),
            ),
            child: _isLoadingReport
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator.adaptive(),
                    ),
                  )
                : Column(
                    children: [
                      _AuditRow(
                        icon: Icons.storage_rounded,
                        iconColor: _report!.hasSufficientStorage
                            ? colors.success
                            : colors.error,
                        title: 'Storage Space',
                        subtitle: _report!.storageStatusText,
                        statusBadge: _report!.hasSufficientStorage ? 'Ready' : 'Low',
                        statusColor: _report!.hasSufficientStorage
                            ? colors.success
                            : colors.error,
                      ),
                      const SizedBox(height: 10),
                      _AuditRow(
                        icon: Icons.speed_rounded,
                        iconColor: colors.primary,
                        title: 'Processor & Cores',
                        subtitle: '${_report!.cpuCores} CPU Cores • ${_report!.performanceTier}',
                        statusBadge: 'Optimized',
                        statusColor: colors.primary,
                      ),
                      const SizedBox(height: 10),
                      _AuditRow(
                        icon: Icons.psychology_rounded,
                        iconColor: colors.syllabotAccent,
                        title: 'RAM & Battery Guard',
                        subtitle: '~350MB Peak RAM • Optimized for energy efficiency',
                        statusBadge: 'Optimal',
                        statusColor: colors.syllabotAccent,
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 20),

          // Download Progress bar if downloading
          if (_isDownloading) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: _downloadProgress,
                backgroundColor: colors.surfaceBorder.withAlpha(80),
                valueColor: AlwaysStoppedAnimation<Color>(colors.primary),
                minHeight: 8,
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                'Downloading model weights (${(_downloadProgress * 100).toInt()}%)...',
                style: typography.caption.medium.copyWith(
                  color: colors.textSecondary,
                  fontSize: 11.5,
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Actions
          if (!_isDownloading) ...[
            ShrinkableButton(
              onTap: () {
                unawaited(HapticFeedback.mediumImpact());
                _startDownload();
              },
              child: Container(
                width: double.infinity,
                height: 48,
                decoration: BoxDecoration(
                  color: colors.primary,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: colors.primary.withAlpha(80),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.download_rounded,
                      size: 18,
                      color: colors.white,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Download & Activate Model (248 MB)',
                      style: typography.callout.bold.copyWith(
                        color: colors.white,
                        fontSize: 13.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(
                  'Continue with Cloud AI Engine (No Storage Needed)',
                  style: typography.caption.medium.copyWith(
                    color: colors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AuditRow extends StatelessWidget {
  const _AuditRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.statusBadge,
    required this.statusColor,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String statusBadge;
  final Color statusColor;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: iconColor.withAlpha(isDark ? 40 : 20),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: iconColor),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: typography.footnote.bold.copyWith(
                  color: colors.textPrimary,
                  fontSize: 12,
                ),
              ),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: typography.caption.regular.copyWith(
                  color: colors.textSecondary,
                  fontSize: 10.5,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
          decoration: BoxDecoration(
            color: statusColor.withAlpha(isDark ? 40 : 20),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: statusColor.withAlpha(isDark ? 70 : 40),
              width: 0.8,
            ),
          ),
          child: Text(
            statusBadge,
            style: typography.caption.bold.copyWith(
              color: statusColor,
              fontSize: 10,
            ),
          ),
        ),
      ],
    );
  }
}
