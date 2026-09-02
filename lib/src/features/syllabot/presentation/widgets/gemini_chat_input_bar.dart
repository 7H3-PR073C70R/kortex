import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/features/syllabot/domain/entities/socratic_mode.dart';
import 'package:kortex/src/features/syllabot/presentation/widgets/speech_to_text_handler.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

/// Gemini-style unified pill input bar for Syllabot AI chat.
///
/// Layout:
/// - Leading '+' attachment / prompt action button.
/// - Fluid multi-line text input field with generous padding.
/// - In-pill Socratic Mode picker pill (`[Step-by-Step ▾]`).
/// - Real-time microphone listening toggle button.
/// - Circular upward send action button when input is populated.
class GeminiChatInputBar extends StatefulWidget {
  const GeminiChatInputBar({
    required this.controller,
    required this.socraticMode,
    required this.onModeChanged,
    required this.onSubmit,
    this.onAttachmentTap,
    this.isLoading = false,
    super.key,
  });

  final TextEditingController controller;
  final SocraticMode socraticMode;
  final ValueChanged<SocraticMode> onModeChanged;
  final ValueChanged<String> onSubmit;
  final VoidCallback? onAttachmentTap;
  final bool isLoading;

  @override
  State<GeminiChatInputBar> createState() => _GeminiChatInputBarState();
}

class _GeminiChatInputBarState extends State<GeminiChatInputBar>
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
                    'Socratic Reasoning Mode',
                    style: typography.title3.bold.copyWith(
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Select how Syllabot structures your academic explanations',
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
                        mode.label,
                        style: typography.body.semiBold.copyWith(
                          color: isSelected
                              ? colors.primary
                              : colors.textPrimary,
                        ),
                      ),
                      subtitle: Text(
                        mode.description,
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

  String _getModeShortLabel(SocraticMode mode) {
    switch (mode) {
      case SocraticMode.stepByStep:
        return 'Step-by-Step';
      case SocraticMode.directAnswer:
        return 'Direct';
      case SocraticMode.examSim:
        return 'Exam Sim';
      case SocraticMode.deepResearch:
        return 'Research';
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
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

              // 2. Multi-line Text Field
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 8,
                  ),
                  child: TextField(
                    controller: widget.controller,
                    maxLines: 5,
                    minLines: 1,
                    textInputAction: TextInputAction.newline,
                    style: typography.body.medium.copyWith(
                      color: colors.textPrimary,
                      fontSize: 15,
                    ),
                    cursorColor: colors.primary,
                    decoration: InputDecoration(
                      hintText: _isListening
                          ? l10n.voiceInputListening
                          : l10n.inputFieldPlaceholder,
                      hintStyle: typography.body.regular.copyWith(
                        color: _isListening
                            ? colors.primary
                            : colors.textSecondary.withAlpha(160),
                        fontSize: 15,
                      ),
                      isDense: true,
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
              ),

              // 3. In-Pill Socratic Mode Selector Dropdown
              ShrinkableButton(
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
                        _getModeShortLabel(widget.socraticMode),
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

              const SizedBox(width: 4),

              // 4. Voice Input (Mic) Button
              ShrinkableButton(
                onTap: _toggleMic,
                child: Padding(
                  padding: const EdgeInsets.all(8),
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

              // 5. Send Action Button (Animated Upward Arrow)
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                transitionBuilder: (child, anim) => ScaleTransition(
                  scale: anim,
                  child: child,
                ),
                child: _hasInput
                    ? ShrinkableButton(
                        key: const ValueKey('send_btn'),
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
                    : const SizedBox.shrink(key: ValueKey('empty_send')),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
