import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kortex/src/core/extensions/snackbar_extension.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/features/syllabot/domain/entities/execution_engine_type.dart';
import 'package:kortex/src/features/syllabot/domain/entities/socratic_mode.dart';
import 'package:kortex/src/features/syllabot/presentation/widgets/input/syllabot_input_mode_pills.dart';
import 'package:kortex/src/features/syllabot/presentation/widgets/input/syllabot_socratic_mode_sheet.dart';
import 'package:kortex/src/features/syllabot/presentation/widgets/input/syllabot_voice_send_action.dart';
import 'package:kortex/src/features/syllabot/presentation/widgets/speech_to_text_handler.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/app_text_field.dart';
import 'package:kortex/src/shared/widgets/platform_hover_builder.dart';
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
    this.isAiSpeaking = false,
    this.onInterruptAi,
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
  final bool isAiSpeaking;
  final VoidCallback? onInterruptAi;

  @override
  State<SyllabotChatInputBar> createState() => _SyllabotChatInputBarState();
}

class _SyllabotChatInputBarState extends State<SyllabotChatInputBar>
    with SingleTickerProviderStateMixin {
  late final SpeechToTextHandler _speechHandler;
  late final AnimationController _micPulseController;
  bool _hasInput = false;
  bool _isListening = false;
  String _textBeforeListening = '';
  Timer? _silenceTimer;

  @override
  void initState() {
    super.initState();
    _hasInput = widget.controller.text.trim().isNotEmpty;
    widget.controller.addListener(_onTextChanged);

    _micPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _speechHandler = SpeechToTextHandler(
      onResult: (text) {
        if (!mounted) return;
        final combined = _textBeforeListening.isNotEmpty
            ? '$_textBeforeListening $text'
            : text;
        setState(() {
          widget.controller.text = combined;
          widget.controller.selection = TextSelection.fromPosition(
            TextPosition(offset: combined.length),
          );
        });
      },
      onResultWithFinal: (text, {required isFinal}) {
        if (!mounted) return;
        _silenceTimer?.cancel();
        if (isFinal) {
          unawaited(_speechHandler.stopListening());
        } else {
          _silenceTimer = Timer(const Duration(milliseconds: 1800), () {
            if (mounted && _isListening) {
              unawaited(_speechHandler.stopListening());
            }
          });
        }
      },
      onListeningChanged: (listening) {
        if (!mounted) return;
        setState(() {
          _isListening = listening;
        });
        if (listening) {
          unawaited(_micPulseController.repeat(reverse: true));
        } else {
          _silenceTimer?.cancel();
          _silenceTimer = null;
          _micPulseController
            ..stop()
            ..reset();
        }
      },
      onError: (err) {
        if (!mounted) return;
        _silenceTimer?.cancel();
        _silenceTimer = null;
        setState(() {
          _isListening = false;
        });
        _micPulseController
          ..stop()
          ..reset();
        context.showSnackBar(
          message: err,
          type: SnackBarType.error,
        );
      },
    );
  }

  @override
  void dispose() {
    _silenceTimer?.cancel();
    widget.controller.removeListener(_onTextChanged);
    _micPulseController.dispose();
    _speechHandler.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(SyllabotChatInputBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isAiSpeaking != oldWidget.isAiSpeaking) {
      if (widget.isAiSpeaking) {
        if (_isListening) {
          unawaited(_speechHandler.stopListening());
        }
        unawaited(_micPulseController.repeat(reverse: true));
      } else if (!_isListening) {
        _micPulseController
          ..stop()
          ..reset();
      }
    }
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

    if (widget.isAiSpeaking) {
      widget.onInterruptAi?.call();
    }

    if (_isListening) {
      unawaited(_speechHandler.stopListening());
    }

    unawaited(HapticFeedback.lightImpact());
    widget.onSubmit(text);
    widget.controller.clear();
    _textBeforeListening = '';
  }

  void _onMicTap() {
    if (widget.isAiSpeaking) {
      unawaited(HapticFeedback.mediumImpact());
      widget.onInterruptAi?.call();
      return;
    }
    if (_isListening) {
      _silenceTimer?.cancel();
      _silenceTimer = null;
      unawaited(_speechHandler.stopListening());
      return;
    }
    if (widget.onVoiceDialogueTap != null) {
      unawaited(HapticFeedback.mediumImpact());
      widget.onVoiceDialogueTap!();
      return;
    }
    _toggleListening();
  }

  void _onMicLongPress() {
    unawaited(HapticFeedback.heavyImpact());
    if (widget.onVoiceDialogueTap != null) {
      widget.onVoiceDialogueTap!();
    } else {
      _toggleListening();
    }
  }

  void _toggleListening() {
    _silenceTimer?.cancel();
    _silenceTimer = null;
    if (widget.isAiSpeaking) {
      // Tap while AI is speaking -> Instant Barge-in Interruption
      unawaited(HapticFeedback.mediumImpact());
      widget.onInterruptAi?.call();
      return;
    }
    if (_isListening) {
      unawaited(_speechHandler.stopListening());
    } else {
      _textBeforeListening = widget.controller.text.trim();
      unawaited(
        _speechHandler.startListening(
          pauseFor: const Duration(milliseconds: 1800),
        ),
      );
    }
  }

  void _showSocraticModeSheet() {
    unawaited(HapticFeedback.selectionClick());
    unawaited(
      SyllabotSocraticModeSheet.show(
        context: context,
        currentMode: widget.socraticMode,
        onModeChanged: widget.onModeChanged,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;
    final isDark = context.isDarkMode;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 860),
        child: ClipRRect(
          borderRadius: AppRadius.radiusDialog,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
              decoration: BoxDecoration(
                color: isDark
                    ? colors.surfacePrimary.withAlpha(210)
                    : colors.surfacePrimary.withAlpha(235),
                borderRadius: AppRadius.radiusDialog,
                border: Border.all(
                  color: isDark
                       ? colors.surfaceBorderHighlight.withAlpha(70)
                      : colors.surfaceBorder,
                  width: 1.1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: colors.black.withAlpha(isDark ? 80 : 15),
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
                      PlatformHoverBuilder(
                        builder: (context, isHovered, child) {
                          return ShrinkableButton(
                            onTap: () {
                              unawaited(HapticFeedback.lightImpact());
                              context.showSnackBar(
                                message:
                                    'Document attachment ready for OCR ingestion',
                              );
                            },
                            child: Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: isHovered
                                    ? colors.primary.withAlpha(25)
                                    : colors.surfaceSecondary,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isHovered
                                      ? colors.primary.withAlpha(120)
                                      : colors.surfaceBorder.withAlpha(90),
                                ),
                              ),
                              child: Icon(
                                Icons.add_rounded,
                                color: isHovered
                                    ? colors.primary
                                    : colors.textSecondary,
                                size: 20,
                              ),
                            ),
                          );
                        },
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
                          hintText: _isListening
                              ? 'Listening… speak now'
                              : l10n.inputFieldPlaceholder,
                          hintStyle: typography.body.regular.copyWith(
                            color: _isListening
                                ? colors.primary.withAlpha(200)
                                : colors.textSecondary.withAlpha(160),
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
                      SyllabotVoiceSendAction(
                        hasInput: _hasInput,
                        isListening: _isListening,
                        isAiSpeaking: widget.isAiSpeaking,
                        isLoading: widget.isLoading,
                        micPulseController: _micPulseController,
                        onSend: _handleSend,
                        onMicTap: _onMicTap,
                        onMicLongPress: _onMicLongPress,
                        hasVoiceDialogue: widget.onVoiceDialogueTap != null,
                      ),
                    ],
                  ),

                  const SizedBox(height: 6),

                  // -------------------------------------------------------------
                  // ROW 2: Mode Selector Pill & AI Engine Switcher Pill
                  // -------------------------------------------------------------
                  SyllabotInputModePills(
                    socraticMode: widget.socraticMode,
                    engineType: widget.engineType,
                    onOpenModeSheet: _showSocraticModeSheet,
                    onEngineChanged: widget.onEngineChanged,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
