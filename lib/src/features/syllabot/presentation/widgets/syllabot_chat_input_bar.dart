import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kortex/src/core/extensions/snackbar_extension.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/features/syllabot/domain/entities/execution_engine_type.dart';
import 'package:kortex/src/features/syllabot/domain/entities/socratic_mode.dart';
import 'package:kortex/src/features/syllabot/presentation/widgets/speech_to_text_handler.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/app_text_field.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

/// Redesigned Syllabot AI input container with 2-row layout:
/// - Row 1: '+' Attachment button, flexible auto-expanding AppTextField,
///   and morphing Mic / Send action.
/// - Row 2: Socratic Reasoning Mode selector and AI Engine switcher.
class SyllabotChatInputBar extends StatefulWidget {
  const SyllabotChatInputBar({
    required this.controller,
    required this.socraticMode,
    required this.engineType,
    required this.onModeChanged,
    required this.onEngineChanged,
    required this.onSubmit,
    this.onVoiceDialogueTap,
    this.isLoading = false,
    super.key,
  });

  final TextEditingController controller;
  final SocraticMode socraticMode;
  final ExecutionEngineType engineType;
  final ValueChanged<SocraticMode> onModeChanged;
  final ValueChanged<ExecutionEngineType> onEngineChanged;
  final ValueChanged<String> onSubmit;
  final VoidCallback? onVoiceDialogueTap;
  final bool isLoading;

  @override
  State<SyllabotChatInputBar> createState() => _SyllabotChatInputBarState();
}

class _SyllabotChatInputBarState extends State<SyllabotChatInputBar> {
  late final SpeechToTextHandler _speechHandler;
  bool _hasInput = false;
  bool _isListening = false;

  @override
  void initState() {
    super.initState();
    _hasInput = widget.controller.text.trim().isNotEmpty;
    widget.controller.addListener(_onTextChanged);

    _speechHandler = SpeechToTextHandler(
      onResult: (text) {
        if (!mounted) return;
        setState(() {
          widget.controller.text = text;
          widget.controller.selection = TextSelection.fromPosition(
            TextPosition(offset: text.length),
          );
        });
      },
      onListeningChanged: (listening) {
        if (!mounted) return;
        setState(() {
          _isListening = listening;
        });
      },
      onError: (err) {
        if (!mounted) return;
        setState(() {
          _isListening = false;
        });
      },
    );
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    _speechHandler.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final hasText = widget.controller.text.trim().isNotEmpty;
    if (hasText != _hasInput) {
      setState(() {
        _hasInput = hasText;
      });
    }
  }

  void _handleSend() {
    final text = widget.controller.text.trim();
    if (text.isEmpty || widget.isLoading) return;

    unawaited(HapticFeedback.lightImpact());
    widget.onSubmit(text);
    widget.controller.clear();
  }

  void _toggleListening() {
    if (_isListening) {
      unawaited(_speechHandler.stopListening());
    } else {
      unawaited(_speechHandler.startListening());
    }
  }

  void _showSocraticModeSheet() {
    unawaited(HapticFeedback.selectionClick());
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;

    unawaited(
      showModalBottomSheet<void>(
        context: context,
        backgroundColor: colors.surfacePrimary,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colors.textSecondary.withAlpha(80),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.socraticModeSheetTitle,
                  style: typography.title3.bold.copyWith(
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.socraticModeSheetSubtitle,
                  style: typography.caption.medium.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
                const SizedBox(height: 16),
                ...SocraticMode.values.map((mode) {
                  final isSelected = mode == widget.socraticMode;
                  final (icon, title, desc) = _getModeDetails(mode, l10n);

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: ShrinkableButton(
                      onTap: () {
                        widget.onModeChanged(mode);
                        Navigator.of(ctx).pop();
                      },
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? colors.primary.withAlpha(25)
                              : colors.surfaceSecondary,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isSelected
                                ? colors.primary
                                : colors.surfaceBorder.withAlpha(80),
                            width: isSelected ? 1.5 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Text(icon, style: const TextStyle(fontSize: 20)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    title,
                                    style: typography.body.bold.copyWith(
                                      color: isSelected
                                          ? colors.primary
                                          : colors.textPrimary,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    desc,
                                    style: typography.caption.regular.copyWith(
                                      color: colors.textSecondary,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (isSelected)
                              Icon(
                                Icons.check_circle_rounded,
                                color: colors.primary,
                                size: 20,
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    ));
  }

  (String icon, String title, String desc) _getModeDetails(
    SocraticMode mode,
    AppLocalizations l10n,
  ) {
    return switch (mode) {
      SocraticMode.stepByStep => (
          '🪜',
          l10n.socraticModeStepByStepLabel,
          l10n.socraticModeStepByStepDesc,
        ),
      SocraticMode.directAnswer => (
          '⚡',
          l10n.socraticModeDirectAnswerLabel,
          l10n.socraticModeDirectAnswerDesc,
        ),
      SocraticMode.examSim => (
          '🎯',
          l10n.socraticModeExamSimLabel,
          l10n.socraticModeExamSimDesc,
        ),
      SocraticMode.deepResearch => (
          '🔬',
          l10n.socraticModeDeepResearchLabel,
          l10n.socraticModeDeepResearchDesc,
        ),
    };
  }

  String _getModeShortLabel(SocraticMode mode, AppLocalizations l10n) {
    return switch (mode) {
      SocraticMode.stepByStep => l10n.socraticModeStepByStepShort,
      SocraticMode.directAnswer => l10n.socraticModeDirectAnswerShort,
      SocraticMode.examSim => l10n.socraticModeExamSimShort,
      SocraticMode.deepResearch => l10n.socraticModeDeepResearchShort,
    };
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;
    final isDark = context.isDarkMode;

    final isCloud = widget.engineType == ExecutionEngineType.cloudSupabase;

    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
          decoration: BoxDecoration(
            color: isDark
                ? colors.surfacePrimary.withAlpha(210)
                : colors.surfacePrimary.withAlpha(235),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: isDark
                  ? colors.surfaceBorderHighlight.withAlpha(70)
                  : colors.surfaceBorder,
              width: 1.1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(isDark ? 80 : 15),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // -------------------------------------------------------------
              // ROW 1: [+] Attachment, Wide AppTextField, Morphing Mic / Send
              // -------------------------------------------------------------
              Row(
                children: [
                  // Attachment '+' button
                  ShrinkableButton(
                    onTap: () {
                      unawaited(HapticFeedback.lightImpact());
                      context.showSnackBar(
                        message: 'Document attachment ready for OCR ingestion',
                      );
                    },
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: colors.surfaceSecondary,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: colors.surfaceBorder.withAlpha(90),
                        ),
                      ),
                      child: Icon(
                        Icons.add_rounded,
                        color: colors.textSecondary,
                        size: 20,
                      ),
                    ),
                  ),

                  const SizedBox(width: 8),

                  // Wide AppTextField expanding from 1 line to 5 lines
                  Expanded(
                    child: AppTextField(
                      controller: widget.controller,
                      showBorder: false,
                      isFilled: false,
                      isDense: true,
                      minLines: 1,
                      maxLines: 5,
                      textInputAction: TextInputAction.newline,
                      hintText: l10n.inputFieldPlaceholder,
                      hintStyle: typography.body.regular.copyWith(
                        color: colors.textSecondary.withAlpha(160),
                        fontSize: 14,
                      ),
                      style: typography.body.medium.copyWith(
                        color: colors.textPrimary,
                        fontSize: 14,
                      ),
                      cursorColor: colors.primary,
                    ),
                  ),

                  const SizedBox(width: 6),

                  // Morphing Trailing Action: Voice Mic vs Send
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    transitionBuilder: (child, anim) => ScaleTransition(
                      scale: anim,
                      child: child,
                    ),
                    child: _hasInput
                        ? ShrinkableButton(
                            key: const ValueKey('send_action'),
                            onTap: _handleSend,
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: colors.primary,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: colors.primary.withAlpha(120),
                                    blurRadius: 10,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: widget.isLoading
                                  ? const Center(
                                      child: SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                            Colors.white,
                                          ),
                                        ),
                                      ),
                                    )
                                  : const Icon(
                                      Icons.arrow_upward_rounded,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                            ),
                          )
                        : ShrinkableButton(
                            key: const ValueKey('voice_action'),
                            onTap: _toggleListening,
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: _isListening
                                    ? colors.error.withAlpha(40)
                                    : colors.surfaceSecondary,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: _isListening
                                      ? colors.error
                                      : colors.surfaceBorder.withAlpha(80),
                                ),
                              ),
                              child: Icon(
                                _isListening
                                    ? Icons.mic_rounded
                                    : Icons.mic_none_rounded,
                                color: _isListening
                                    ? colors.error
                                    : colors.textSecondary,
                                size: 20,
                              ),
                            ),
                          ),
                  ),
                ],
              ),

              const SizedBox(height: 6),

              // -------------------------------------------------------------
              // ROW 2: Mode Selector Pill & AI Engine Switcher Pill
              // -------------------------------------------------------------
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // 1. Socratic Mode Selector Pill
                  ShrinkableButton(
                    onTap: _showSocraticModeSheet,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: colors.surfaceSecondary,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: colors.surfaceBorder.withAlpha(90),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _getModeDetails(widget.socraticMode, l10n).$1,
                            style: const TextStyle(fontSize: 13),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _getModeShortLabel(widget.socraticMode, l10n),
                            style: typography.caption.bold.copyWith(
                              color: colors.textPrimary,
                              fontSize: 11.5,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: colors.textSecondary,
                            size: 15,
                          ),
                        ],
                      ),
                    ),
                  ),

                  // 2. AI Engine Switcher Pill
                  ShrinkableButton(
                    onTap: () {
                      unawaited(HapticFeedback.selectionClick());
                      final next = isCloud
                          ? ExecutionEngineType.localOnDevice
                          : ExecutionEngineType.cloudSupabase;
                      widget.onEngineChanged(next);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: colors.surfaceSecondary,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: colors.surfaceBorder.withAlpha(90),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isCloud
                                  ? const Color(0xFF10B981)
                                  : const Color(0xFFF59E0B),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            isCloud
                                ? l10n.engineCloudSupabase
                                : l10n.engineLocalOnDevice,
                            style: typography.caption.bold.copyWith(
                              color: colors.textPrimary,
                              fontSize: 11.5,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.swap_horiz_rounded,
                            color: colors.textSecondary,
                            size: 15,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
