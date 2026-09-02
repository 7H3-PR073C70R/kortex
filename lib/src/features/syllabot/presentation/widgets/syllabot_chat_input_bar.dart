import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/features/syllabot/domain/entities/socratic_mode.dart';
import 'package:kortex/src/features/syllabot/presentation/widgets/speech_to_text_handler.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/app_text_field.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

/// Syllabot AI unified input bar with dynamic expanding multi-line textfield,
/// in-pill Socratic mode selector, and animated morphing voice/send button.
class SyllabotChatInputBar extends StatefulWidget {
  const SyllabotChatInputBar({
    required this.controller,
    required this.socraticMode,
    required this.onModeChanged,
    required this.onSubmit,
    this.onAttachmentTap,
    this.onVoiceDialogueTap,
    this.isLoading = false,
    super.key,
  });

  final TextEditingController controller;
  final SocraticMode socraticMode;
  final ValueChanged<SocraticMode> onModeChanged;
  final ValueChanged<String> onSubmit;
  final VoidCallback? onAttachmentTap;
  final VoidCallback? onVoiceDialogueTap;
  final bool isLoading;

  @override
  State<SyllabotChatInputBar> createState() => _SyllabotChatInputBarState();
}

class _SyllabotChatInputBarState extends State<SyllabotChatInputBar>
    with SingleTickerProviderStateMixin {
  bool _hasInput = false;
  bool _isListening = false;
  late final SpeechToTextHandler _sttHandler;
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _hasInput = widget.controller.text.trim().isNotEmpty;
    widget.controller.addListener(_onTextChanged);

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    unawaited(_pulseController.repeat(reverse: true));

    _sttHandler = SpeechToTextHandler(
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
    );
  }

  void _onTextChanged() {
    final hasText = widget.controller.text.trim().isNotEmpty;
    if (hasText != _hasInput) {
      setState(() {
        _hasInput = hasText;
      });
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    _pulseController.dispose();
    _sttHandler.dispose();
    super.dispose();
  }

  void _handleSend() {
    final text = widget.controller.text.trim();
    if (text.isEmpty || widget.isLoading) return;

    if (_isListening) {
      unawaited(_sttHandler.stopListening());
    }

    widget.onSubmit(text);
    widget.controller.clear();
  }

  void _toggleMic() {
    if (_isListening) {
      unawaited(_sttHandler.stopListening());
    } else {
      unawaited(_sttHandler.startListening());
    }
  }

  void _showModeMenu(BuildContext context) {
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
        builder: (sheetContext) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: colors.textSecondary.withAlpha(60),
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
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      tileColor: isSelected
                          ? colors.primary.withAlpha(25)
                          : Colors.transparent,
                      leading: Icon(
                        _getModeIcon(mode),
                        color: isSelected
                            ? colors.primary
                            : colors.textSecondary,
                      ),
                      title: Text(
                        _getLocalizedModeLabel(mode, l10n),
                        style: typography.body.semiBold.copyWith(
                          color: isSelected
                              ? colors.primary
                              : colors.textPrimary,
                        ),
                      ),
                      subtitle: Text(
                        _getLocalizedModeDescription(mode, l10n),
                        style: typography.caption.regular.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                      trailing: isSelected
                          ? Icon(
                              Icons.check_circle_rounded,
                              color: colors.primary,
                              size: 20,
                            )
                          : null,
                      onTap: () {
                        unawaited(HapticFeedback.selectionClick());
                        widget.onModeChanged(mode);
                        Navigator.of(sheetContext).pop();
                      },
                    );
                  }),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  String _getLocalizedModeLabel(SocraticMode mode, AppLocalizations l10n) {
    switch (mode) {
      case SocraticMode.stepByStep:
        return l10n.socraticModeStepByStepLabel;
      case SocraticMode.directAnswer:
        return l10n.socraticModeDirectAnswerLabel;
      case SocraticMode.examSim:
        return l10n.socraticModeExamSimLabel;
      case SocraticMode.deepResearch:
        return l10n.socraticModeDeepResearchLabel;
    }
  }

  String _getLocalizedModeDescription(
      SocraticMode mode, AppLocalizations l10n) {
    switch (mode) {
      case SocraticMode.stepByStep:
        return l10n.socraticModeStepByStepDesc;
      case SocraticMode.directAnswer:
        return l10n.socraticModeDirectAnswerDesc;
      case SocraticMode.examSim:
        return l10n.socraticModeExamSimDesc;
      case SocraticMode.deepResearch:
        return l10n.socraticModeDeepResearchDesc;
    }
  }

  IconData _getModeIcon(SocraticMode mode) {
    switch (mode) {
      case SocraticMode.stepByStep:
        return Icons.alt_route_rounded;
      case SocraticMode.directAnswer:
        return Icons.bolt_rounded;
      case SocraticMode.examSim:
        return Icons.quiz_outlined;
      case SocraticMode.deepResearch:
        return Icons.menu_book_rounded;
    }
  }

  String _getModeShortLabel(SocraticMode mode, AppLocalizations l10n) {
    switch (mode) {
      case SocraticMode.stepByStep:
        return l10n.socraticModeStepByStepShort;
      case SocraticMode.directAnswer:
        return l10n.socraticModeDirectAnswerShort;
      case SocraticMode.examSim:
        return l10n.socraticModeExamSimShort;
      case SocraticMode.deepResearch:
        return l10n.socraticModeDeepResearchShort;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final isDark = context.isDarkMode;
    final l10n = context.l10n;

    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? colors.surfaceSecondary.withAlpha(220)
            : colors.surfaceSecondary.withAlpha(180),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: isDark
              ? colors.surfaceBorderHighlight.withAlpha(55)
              : colors.surfaceBorder.withAlpha(140),
          width: 1.1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(isDark ? 50 : 12),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // 1. Plus / Attachment action
          ShrinkableButton(
            onTap: widget.onAttachmentTap ?? () {},
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Icon(
                Icons.add_rounded,
                color: colors.textSecondary,
                size: 24,
              ),
            ),
          ),

          // 2. Wide Multi-line Reusable AppTextField (1 line initially, max 5)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: AppTextField(
                controller: widget.controller,
                minLines: 1,
                maxLines: 5,
                showBorder: false,
                isFilled: false,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 4,
                  vertical: 8,
                ),
                textInputAction: TextInputAction.newline,
                style: typography.body.medium.copyWith(
                  color: colors.textPrimary,
                  fontSize: 15,
                ),
                cursorColor: colors.primary,
                hintText: _isListening
                    ? l10n.voiceInputListening
                    : l10n.inputFieldPlaceholder,
                hintStyle: typography.body.regular.copyWith(
                  color: _isListening
                      ? colors.primary
                      : colors.textSecondary.withAlpha(160),
                  fontSize: 15,
                ),
              ),
            ),
          ),

          // 3. Compact In-Pill Socratic Mode Selector
          Padding(
            padding: const EdgeInsets.only(bottom: 5),
            child: ShrinkableButton(
              onTap: () => _showModeMenu(context),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: colors.surfacePrimary.withAlpha(isDark ? 160 : 220),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isDark
                        ? colors.surfaceBorderHighlight.withAlpha(40)
                        : colors.surfaceBorder.withAlpha(100),
                    width: 0.8,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _getModeShortLabel(widget.socraticMode, l10n),
                      style: typography.caption.bold.copyWith(
                        color: colors.textPrimary,
                        fontSize: 11.5,
                      ),
                    ),
                    const SizedBox(width: 3),
                    Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: colors.textSecondary,
                      size: 16,
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(width: 4),

          // 4. Morphing Trailing Action: Voice Mic (when empty) vs
          // Send (when typed)
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              transitionBuilder: (child, anim) => ScaleTransition(
                scale: anim,
                child: child,
              ),
              child: _hasInput
                  ? ShrinkableButton(
                      key: const ValueKey('send_button'),
                      onTap: _handleSend,
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: colors.primary,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: colors.primary.withAlpha(90),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.arrow_upward_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    )
                  : ShrinkableButton(
                      key: const ValueKey('mic_button'),
                      onTap: _toggleMic,
                      child: Padding(
                        padding: const EdgeInsets.all(7),
                        child: _isListening
                            ? AnimatedBuilder(
                                animation: _pulseController,
                                builder: (context, child) {
                                  return Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: colors.error.withAlpha(
                                        (120 + (_pulseController.value * 120))
                                            .toInt(),
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.mic_rounded,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                  );
                                },
                              )
                            : Icon(
                                Icons.mic_none_rounded,
                                color: colors.textSecondary,
                                size: 22,
                              ),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
