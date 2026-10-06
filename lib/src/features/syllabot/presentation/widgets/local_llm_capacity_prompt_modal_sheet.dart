import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_llama/flutter_llama.dart';
import 'package:kortex/src/core/extensions/snackbar_extension.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/device_capability_service.dart';
import 'package:kortex/src/core/themes/app_motion.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/syllabot/data/client/local_llm_engine_client.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/app_adaptive_sheet.dart';
import 'package:kortex/src/shared/widgets/platform_hover_builder.dart';
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
    return AppAdaptiveSheet.showModal<bool>(
      context: context,
      builder: (_) => LocalLlmCapacityPromptModalSheet(
        onDownloadComplete: onDownloadComplete,
      ),
    );
  }

  @override
  State<LocalLlmCapacityPromptModalSheet> createState() =>
      _LocalLlmCapacityPromptModalSheetState();
}

class _LocalLlmModelSpec {
  const _LocalLlmModelSpec({
    required this.name,
    required this.sizeLabel,
    required this.requiredMb,
    required this.badgeLabel,
    required this.ramSubtitle,
    required this.preset,
  });

  final String name;
  final String sizeLabel;
  final int requiredMb;
  final String badgeLabel;
  final String ramSubtitle;
  final PresetModel preset;
}

const _kAvailableModels = [
  _LocalLlmModelSpec(
    name: 'SmolLM2 135M',
    sizeLabel: '100 MB',
    requiredMb: 100,
    badgeLabel: '100 MB • Fast & Lightweight',
    ramSubtitle: '~250MB Peak RAM • Optimized for energy efficiency',
    preset: PresetModels.smolLM2Q4K,
  ),
  _LocalLlmModelSpec(
    name: 'Qwen 2.5 0.5B',
    sizeLabel: '350 MB',
    requiredMb: 350,
    badgeLabel: '350 MB • Deep STEM Reasoning',
    ramSubtitle: '~500MB Peak RAM • High performance small LM',
    preset: PresetModels.qwen25Q4K,
  ),
];

class _LocalLlmCapacityPromptModalSheetState
    extends State<LocalLlmCapacityPromptModalSheet> {
  int _selectedModelIndex = 0;
  DeviceCapabilityReport? _report;
  bool _isLoadingReport = true;
  bool _isDownloading = false;
  double _downloadProgress = 0;
  StreamSubscription<double>? _downloadSub;

  _LocalLlmModelSpec get _selectedModelSpec =>
      _kAvailableModels[_selectedModelIndex.clamp(0, _kAvailableModels.length - 1)];

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
    final selectedModel = _selectedModelSpec;
    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.05;
    });

    _downloadSub = client.downloadModel(preset: selectedModel.preset).listen(
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
            message: '${selectedModel.name} On-Device Neural Engine ready (${selectedModel.sizeLabel})! Activated.',
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
    final l10n = context.l10n;
    final selectedModel = _selectedModelSpec;
    final hasSufficientStorage = _report != null &&
        _report!.availableStorageMb >= selectedModel.requiredMb;
    final storageStatusText = hasSufficientStorage
        ? 'Sufficient space available (${selectedModel.sizeLabel} required)'
        : 'Low storage warning (${selectedModel.sizeLabel} required)';

    final isDesktop = AppAdaptiveSheet.isDesktopOrWeb(context);

    return Align(
      alignment: isDesktop ? Alignment.center : Alignment.bottomCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: Container(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: isDesktop ? 24 : 16,
            bottom: isDesktop
                ? 24
                : MediaQuery.of(context).viewInsets.bottom + 28,
          ),
          decoration: BoxDecoration(
            color: isDark ? colors.surfacePrimary : colors.backgroundPrimary,
            borderRadius: isDesktop
                ? BorderRadius.circular(AppRadius.dialog)
                : const BorderRadius.vertical(
                    top: Radius.circular(AppRadius.dialog),
                  ),
            border: Border.all(
              color: isDark
                  ? colors.surfaceBorderHighlight.withAlpha(50)
                  : colors.surfaceBorder.withAlpha(120),
            ),
            boxShadow: isDesktop
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.25),
                      blurRadius: 28,
                      offset: const Offset(0, 14),
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isDesktop) ...[
                // Drag Handle
                Center(
                  child: Container(
                    width: 38,
                    height: 4.5,
                    decoration: BoxDecoration(
                      color: colors.textSecondary.withAlpha(80),
                      borderRadius: AppRadius.radiusMicro,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
              ],

              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: colors.primary.withAlpha(isDark ? 50 : 25),
                      borderRadius: AppRadius.radiusCard,
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
                          'Quantized 4-bit Neural Model (${selectedModel.sizeLabel})',
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
              const SizedBox(height: 14),

              // Model Choice Cards
              Row(
                children: List.generate(_kAvailableModels.length, (index) {
                  final model = _kAvailableModels[index];
                  final isSelected = _selectedModelIndex == index;
                  return Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(left: index > 0 ? 8.0 : 0.0),
                      child: ShrinkableButton(
                        onTap: () => setState(() => _selectedModelIndex = index),
                        child: AnimatedContainer(
                          duration: AppMotion.snappy,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? colors.primary.withAlpha(isDark ? 40 : 20)
                                : colors.surfaceSecondary,
                            borderRadius: AppRadius.radiusCard,
                            border: Border.all(
                              color: isSelected
                                  ? colors.primary
                                  : colors.surfaceBorder.withAlpha(60),
                              width: isSelected ? 1.5 : 1,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                model.name,
                                style: typography.caption.bold.copyWith(
                                  color: isSelected
                                      ? colors.primary
                                      : colors.textPrimary,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                model.badgeLabel,
                                style: typography.caption.regular.copyWith(
                                  color: colors.textSecondary,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 14),

              // Device Capability Audit Box
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark
                      ? colors.surfaceSecondary.withAlpha(140)
                      : colors.surfaceSecondary.withAlpha(90),
                  borderRadius: AppRadius.radiusPanel,
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
                            iconColor: hasSufficientStorage
                                ? colors.success
                                : colors.error,
                            title: l10n.syllabotCapStorageSpace,
                            subtitle: storageStatusText,
                            statusBadge: hasSufficientStorage
                                ? 'Ready'
                                : 'Low',
                            statusColor: hasSufficientStorage
                                ? colors.success
                                : colors.error,
                          ),
                          const SizedBox(height: 10),
                          _AuditRow(
                            icon: Icons.speed_rounded,
                            iconColor: colors.primary,
                            title: l10n.syllabotCapProcessorCores,
                            subtitle:
                                '${_report!.cpuCores} CPU Cores • ${_report!.performanceTier}',
                            statusBadge: 'Optimized',
                            statusColor: colors.primary,
                          ),
                          const SizedBox(height: 10),
                          _AuditRow(
                            icon: Icons.psychology_rounded,
                            iconColor: colors.syllabotAccent,
                            title: l10n.syllabotCapRamBatteryGuard,
                            subtitle: selectedModel.ramSubtitle,
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
                  borderRadius: AppRadius.radiusMicro,
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
                    'Downloading ${selectedModel.name} weights (${(_downloadProgress * 100).toInt()}%)...',
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
                PlatformHoverBuilder(
                  builder: (context, isHovered, child) {
                    return ShrinkableButton(
                      onTap: () {
                        unawaited(HapticFeedback.mediumImpact());
                        _startDownload();
                      },
                      child: AnimatedContainer(
                        duration: AppMotion.snappy,
                        curve: AppMotion.snappyCurve,
                        width: double.infinity,
                        height: 48,
                        decoration: BoxDecoration(
                          color: isHovered
                              ? colors.primary.withAlpha(235)
                              : colors.primary,
                          borderRadius: AppRadius.radiusCard,
                          boxShadow: [
                            BoxShadow(
                              color: colors.black.withAlpha(
                                isHovered
                                    ? (isDark ? 55 : 25)
                                    : (isDark ? 35 : 15),
                              ),
                              blurRadius: isHovered ? 14 : 10,
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
                              'Download & Activate Model (${selectedModel.sizeLabel})',
                              style: typography.callout.bold.copyWith(
                                color: colors.white,
                                fontSize: 13.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
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
        ),
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
            borderRadius: AppRadius.radiusBadge,
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
            borderRadius: AppRadius.radiusMicro,
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
