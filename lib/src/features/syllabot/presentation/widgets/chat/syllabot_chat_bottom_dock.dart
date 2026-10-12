import 'package:flutter/material.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/features/monetization/domain/services/subscription_guard.dart';
import 'package:kortex/src/features/syllabot/domain/entities/execution_engine_type.dart';
import 'package:kortex/src/features/syllabot/domain/entities/socratic_mode.dart';
import 'package:kortex/src/features/syllabot/presentation/bloc/syllabot_chat_state.dart';
import 'package:kortex/src/features/syllabot/presentation/widgets/local_llm_download_bar.dart';
import 'package:kortex/src/features/syllabot/presentation/widgets/syllabot_chat_input_bar.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

/// Bottom dock of Syllabot Chat including quota counter, model download progress, and input bar.
class SyllabotChatBottomDock extends StatelessWidget {
  const SyllabotChatBottomDock({
    required this.controller,
    required this.state,
    required this.isDownloadingModel,
    required this.downloadProgress,
    required this.isAiSpeaking,
    required this.isPro,
    required this.usedQueries,
    required this.onCancelDownload,
    required this.onInterruptAi,
    required this.onVoiceDialogueTap,
    required this.onModeChanged,
    required this.onEngineChanged,
    required this.onSubmit,
    required this.onUpgradeTap,
    super.key,
  });

  final TextEditingController controller;
  final SyllabotChatState state;
  final bool isDownloadingModel;
  final double downloadProgress;
  final bool isAiSpeaking;
  final bool isPro;
  final int usedQueries;
  final VoidCallback onCancelDownload;
  final VoidCallback onInterruptAi;
  final VoidCallback? onVoiceDialogueTap;
  final ValueChanged<SocraticMode> onModeChanged;
  final ValueChanged<ExecutionEngineType> onEngineChanged;
  final ValueChanged<String> onSubmit;
  final VoidCallback onUpgradeTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;

    const limit = SubscriptionGuard.freeDailySyllabotLimit;
    final isLocalEngine = state.engineType == ExecutionEngineType.localOnDevice;
    final isExhausted = !isLocalEngine && usedQueries >= limit;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!isPro)
          Padding(
            padding: const EdgeInsets.only(
              left: 18,
              right: 18,
              bottom: 6,
            ),
            child: ShrinkableButton(
              onTap: onUpgradeTap,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: (isExhausted ? colors.error : colors.primary)
                      .withAlpha(isDark ? 30 : 16),
                  borderRadius: BorderRadius.circular(
                    AppRadius.card,
                  ),
                  border: Border.all(
                    color: (isExhausted ? colors.error : colors.primary)
                        .withAlpha(isDark ? 80 : 50),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isLocalEngine
                          ? Icons.offline_bolt_rounded
                          : Icons.auto_awesome_rounded,
                      size: 13,
                      color: isExhausted ? colors.error : colors.primary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isLocalEngine
                          ? 'On-Device AI • Unlimited queries'
                          : '$usedQueries / $limit free queries used today',
                      style: typography.caption.medium.copyWith(
                        color: colors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Upgrade',
                      style: typography.caption.bold.copyWith(
                        color: colors.primary,
                        fontSize: 11,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
          child: isDownloadingModel
              ? LocalLlmDownloadBar(
                  progress: downloadProgress,
                  onCancel: onCancelDownload,
                  currentEngine: state.engineType,
                )
              : SyllabotChatInputBar(
                  controller: controller,
                  socraticMode: state.socraticMode,
                  engineType: state.engineType,
                  isLoading:
                      state.status == SyllabotStatus.streaming ||
                      state.isGeneratingDeck,
                  isAiSpeaking: isAiSpeaking,
                  onInterruptAi: onInterruptAi,
                  onVoiceDialogueTap: onVoiceDialogueTap,
                  onModeChanged: onModeChanged,
                  onEngineChanged: onEngineChanged,
                  onSubmit: onSubmit,
                ),
        ),
      ],
    );
  }
}
