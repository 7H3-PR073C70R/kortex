import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kortex/src/core/extensions/snackbar_extension.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/features/syllabot/domain/entities/execution_engine_type.dart';
import 'package:kortex/src/features/syllabot/domain/entities/socratic_mode.dart';
import 'package:kortex/src/features/syllabot/presentation/widgets/speech_to_text_handler.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/app_logo_loader.dart';
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
        if (listening) {
          unawaited(_micPulseController.repeat(reverse: true));
        } else {
          _micPulseController
            ..stop()
            ..reset();
        }
      },
      onError: (err) {
        if (!mounted) return;
        setState(() {
          _isListening = false;
        });
        _micPulseController
          ..stop()
          ..reset();
      },
    );
  }

  @override
  void dispose() {
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

    unawaited(HapticFeedback.lightImpact());
    widget.onSubmit(text);
    widget.controller.clear();
  }

  void _toggleListening() {
    if (widget.isAiSpeaking) {
      // Tap while AI is speaking -> Instant Barge-in Interruption
      unawaited(HapticFeedback.mediumImpact());
      widget.onInterruptAi?.call();
      return;
    }
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
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.dialog),
          ),
        ),
        builder: (ctx) {
          return SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
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
                            color: colors.textSecondary.withAlpha(80),
                            borderRadius: AppRadius.radiusMicro,
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
                                borderRadius: AppRadius.radiusCard,
                                border: Border.all(
                                  color: isSelected
                                      ? colors.primary
                                      : colors.surfaceBorder.withAlpha(80),
                                  width: isSelected ? 1.5 : 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Text(
                                    icon,
                                    style: context.typography.body.regular.copyWith(fontSize: 20),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
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
                                          style: typography.caption.regular
                                              .copyWith(
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
              ),
            ),
          );
        },
      ),
    );
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
      SocraticMode.feynmanTeachBack => (
        '🧠',
        'Feynman Teach-Back',
        'Explain simply to Syllabot; AI diagnoses missing concepts and jargon',
      ),
    };
  }

  String _getModeShortLabel(SocraticMode mode, AppLocalizations l10n) {
    return switch (mode) {
      SocraticMode.stepByStep => l10n.socraticModeStepByStepShort,
      SocraticMode.directAnswer => l10n.socraticModeDirectAnswerShort,
      SocraticMode.examSim => l10n.socraticModeExamSimShort,
      SocraticMode.deepResearch => l10n.socraticModeDeepResearchShort,
      SocraticMode.feynmanTeachBack => 'Feynman Mode',
    };
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
                            ? PlatformHoverBuilder(
                                key: const ValueKey('send_action'),
                                builder: (context, isHovered, child) {
                                  return ShrinkableButton(
                                    onTap: _handleSend,
                                    child: Container(
                                      width: 36,
                                      height: 36,
                                      decoration: BoxDecoration(
                                        color: colors.primary,
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: colors.black.withAlpha(
                                              isHovered ? 50 : 25,
                                            ),
                                            blurRadius: isHovered ? 12 : 8,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: widget.isLoading
                                          ? Center(
                                              child: AppLogoLoader(
                                                size: 18,
                                                color: colors.white,
                                                showMessage: false,
                                              ),
                                            )
                                          : Icon(
                                              Icons.arrow_upward_rounded,
                                              color: colors.white,
                                              size: 20,
                                            ),
                                    ),
                                  );
                                },
                              )
                            : AnimatedBuilder(
                                animation: _micPulseController,
                                builder: (context, _) {
                                  final pulse = _micPulseController.value;
                                  final isAiSpeaking = widget.isAiSpeaking;
                                  return Tooltip(
                                    message: isAiSpeaking
                                        ? 'Syllabot is speaking • Tap to interrupt'
                                        : (_isListening
                                              ? 'Listening...'
                                              : 'Voice Input'),
                                    child: PlatformHoverBuilder(
                                      key: ValueKey(
                                        isAiSpeaking
                                            ? 'ai_speaking_action'
                                            : 'voice_action',
                                      ),
                                      builder: (context, isHovered, child) {
                                        return ShrinkableButton(
                                          onTap: _toggleListening,
                                          child: Stack(
                                            alignment: Alignment.center,
                                            children: [
                                              if (_isListening || isAiSpeaking)
                                                Container(
                                                  width: 36 + (pulse * 12),
                                                  height: 36 + (pulse * 12),
                                                  decoration: BoxDecoration(
                                                    shape: BoxShape.circle,
                                                    color: isAiSpeaking
                                                        ? colors.syllabotAccent
                                                              .withAlpha(
                                                                (70 * (1 - pulse))
                                                                    .toInt(),
                                                              )
                                                        : colors.error.withAlpha(
                                                            (90 * (1 - pulse))
                                                                .toInt(),
                                                          ),
                                                  ),
                                                ),
                                              Container(
                                                width: 36,
                                                height: 36,
                                                decoration: BoxDecoration(
                                                  color: isAiSpeaking
                                                      ? colors.syllabotAccent
                                                            .withAlpha(45)
                                                      : (_isListening
                                                            ? colors.error
                                                            : (isHovered
                                                                  ? colors
                                                                        .primary
                                                                        .withAlpha(
                                                                          20,
                                                                        )
                                                                  : colors
                                                                        .surfaceSecondary)),
                                                  shape: BoxShape.circle,
                                                  boxShadow:
                                                      (isAiSpeaking ||
                                                          _isListening)
                                                      ? [
                                                          BoxShadow(
                                                            color: colors.black
                                                                .withAlpha(
                                                                  isDark
                                                                      ? 50
                                                                      : 20,
                                                                ),
                                                            blurRadius: 10,
                                                            offset:
                                                                const Offset(
                                                                  0,
                                                                  3,
                                                                ),
                                                          ),
                                                        ]
                                                      : null,
                                                  border: Border.all(
                                                    color: isAiSpeaking
                                                        ? colors.syllabotAccent
                                                        : (_isListening
                                                              ? colors.white
                                                                    .withAlpha(
                                                                      180,
                                                                    )
                                                              : (isHovered
                                                                    ? colors
                                                                          .primary
                                                                          .withAlpha(
                                                                            120,
                                                                          )
                                                                    : colors
                                                                          .surfaceBorder
                                                                          .withAlpha(
                                                                            80,
                                                                          ))),
                                                    width: isAiSpeaking
                                                        ? 1.5
                                                        : 1,
                                                  ),
                                                ),
                                                child: Icon(
                                                  isAiSpeaking
                                                      ? Icons.graphic_eq_rounded
                                                      : (_isListening
                                                            ? Icons.mic_rounded
                                                            : Icons
                                                                  .mic_none_rounded),
                                                  color: isAiSpeaking
                                                      ? colors.syllabotAccent
                                                      : (_isListening
                                                            ? colors.white
                                                            : (isHovered
                                                                  ? colors
                                                                        .primary
                                                                  : colors
                                                                        .textSecondary)),
                                                  size: 20,
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                                  );
                                },
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
                      Flexible(
                        child: PlatformHoverBuilder(
                          builder: (context, isHovered, child) {
                            return ShrinkableButton(
                              onTap: _showSocraticModeSheet,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: isHovered
                                      ? colors.primary.withAlpha(20)
                                      : colors.surfaceSecondary,
                                  borderRadius: AppRadius.radiusBadge,
                                  border: Border.all(
                                    color: isHovered
                                        ? colors.primary.withAlpha(120)
                                        : colors.surfaceBorder.withAlpha(90),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      _getModeDetails(
                                        widget.socraticMode,
                                        l10n,
                                      ).$1,
                                      style: context.typography.body.regular.copyWith(fontSize: 13),
                                    ),
                                    const SizedBox(width: 6),
                                    Flexible(
                                      child: Text(
                                        _getModeShortLabel(
                                          widget.socraticMode,
                                          l10n,
                                        ),
                                        style: typography.caption.bold.copyWith(
                                          color: isHovered
                                              ? colors.primary
                                              : colors.textPrimary,
                                          fontSize: 11.5,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Icon(
                                      Icons.keyboard_arrow_down_rounded,
                                      color: isHovered
                                          ? colors.primary
                                          : colors.textSecondary,
                                      size: 15,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 8),

                      // 2. Interactive AI Engine Pill (Cloud AI / On-Device AI)
                      PlatformHoverBuilder(
                        builder: (context, isHovered, child) {
                          return ShrinkableButton(
                            onTap: () {
                              unawaited(HapticFeedback.lightImpact());
                              final nextEngine =
                                  widget.engineType ==
                                      ExecutionEngineType.cloudRemote
                                  ? ExecutionEngineType.localOnDevice
                                  : ExecutionEngineType.cloudRemote;
                              widget.onEngineChanged(nextEngine);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: isHovered
                                    ? colors.primary.withAlpha(20)
                                    : colors.surfaceSecondary,
                                borderRadius: AppRadius.radiusBadge,
                                border: Border.all(
                                  color: isHovered
                                      ? colors.primary.withAlpha(120)
                                      : colors.surfaceBorder.withAlpha(90),
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
                                      color:
                                          widget.engineType ==
                                              ExecutionEngineType.cloudRemote
                                          ? colors.success
                                          : colors.primary,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    widget.engineType ==
                                            ExecutionEngineType.cloudRemote
                                        ? l10n.engineCloudSupabase
                                        : l10n.engineLocalOnDevice,
                                    style: typography.caption.bold.copyWith(
                                      color: isHovered
                                          ? colors.primary
                                          : colors.textPrimary,
                                      fontSize: 11.5,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ],
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
