import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/features/syllabot/domain/entities/chat_message_entity.dart';
import 'package:kortex/src/features/syllabot/domain/entities/socratic_mode.dart';
import 'package:kortex/src/features/syllabot/presentation/widgets/chat_bubble_widget.dart';
import 'package:kortex/src/features/syllabot/presentation/widgets/speech_to_text_handler.dart';
import 'package:kortex/src/features/syllabot/presentation/widgets/text_to_speech_handler.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

enum DialogueState {
  listening,
  thinking,
  speaking,
  idle,
}

/// Full-screen interactive voice dialogue mode with live audio waveform,
/// bidirectional speech-to-text / text-to-speech, and voice gender toggle.
class VoiceDialogueModal extends StatefulWidget {
  const VoiceDialogueModal({
    required this.onSendPrompt,
    required this.ttsHandler,
    this.initialMode = SocraticMode.stepByStep,
    super.key,
  });

  final Future<String> Function(String prompt) onSendPrompt;
  final TextToSpeechHandler ttsHandler;
  final SocraticMode initialMode;

  static Future<void> show({
    required BuildContext context,
    required Future<String> Function(String prompt) onSendPrompt,
    required TextToSpeechHandler ttsHandler,
    SocraticMode initialMode = SocraticMode.stepByStep,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => VoiceDialogueModal(
        onSendPrompt: onSendPrompt,
        ttsHandler: ttsHandler,
        initialMode: initialMode,
      ),
    );
  }

  @override
  State<VoiceDialogueModal> createState() => _VoiceDialogueModalState();
}

class _VoiceDialogueModalState extends State<VoiceDialogueModal>
    with SingleTickerProviderStateMixin {
  late final SpeechToTextHandler _sttHandler;
  late final AnimationController _pulseController;

  DialogueState _state = DialogueState.idle;
  String _liveTranscript = '';
  String _latestResponse = '';
  late VoiceGender _selectedGender;

  @override
  void initState() {
    super.initState();
    _selectedGender = widget.ttsHandler.voiceGender;

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    unawaited(_pulseController.repeat(reverse: true));

    _sttHandler = SpeechToTextHandler(
      onResult: (text) {
        if (!mounted) return;
        setState(() {
          _liveTranscript = text;
        });
      },
      onListeningChanged: (listening) {
        if (!mounted) return;
        if (!listening && _state == DialogueState.listening) {
          if (_liveTranscript.trim().isNotEmpty) {
            unawaited(_processVoicePrompt(_liveTranscript.trim()));
          } else {
            setState(() {
              _state = DialogueState.idle;
            });
          }
        }
      },
      onError: (err) {
        if (mounted) {
          setState(() {
            _state = DialogueState.idle;
          });
        }
      },
    );

    // Speak initial AI greeting before listening
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_speakInitialGreeting());
    });
  }

  Future<void> _speakInitialGreeting() async {
    const greeting =
        "Hello! I'm Syllabot. What topic or problem would you like to explore "
        'together today?';
    if (!mounted) return;
    setState(() {
      _latestResponse = greeting;
      _state = DialogueState.speaking;
    });

    await widget.ttsHandler.speak(greeting);
    if (mounted && _state == DialogueState.speaking) {
      await _startListening();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _sttHandler.dispose();
    super.dispose();
  }

  Future<void> _startListening() async {
    await widget.ttsHandler.stop();
    setState(() {
      _state = DialogueState.listening;
      _liveTranscript = '';
    });
    await _sttHandler.startListening();
  }

  Future<void> _processVoicePrompt(String prompt) async {
    setState(() {
      _state = DialogueState.thinking;
    });

    try {
      final response = await widget.onSendPrompt(prompt);
      if (!mounted) return;

      setState(() {
        _latestResponse = response;
        _state = DialogueState.speaking;
      });

      await widget.ttsHandler.speak(response);

      if (mounted) {
        setState(() {
          _state = DialogueState.idle;
        });
      }
    } on Object catch (_) {
      if (mounted) {
        setState(() {
          _state = DialogueState.idle;
        });
      }
    }
  }

  void _toggleGender() {
    unawaited(HapticFeedback.selectionClick());
    setState(() {
      _selectedGender = _selectedGender == VoiceGender.female
          ? VoiceGender.male
          : VoiceGender.female;
    });
    unawaited(widget.ttsHandler.setVoiceGender(_selectedGender));
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final l10n = context.l10n;

    return Container(
      decoration: BoxDecoration(
        color: colors.backgroundPrimary,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            children: [
              // 1. Header Drag Handle & Controls
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Voice Gender Selector Pill
                  ShrinkableButton(
                    onTap: _toggleGender,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: colors.surfaceSecondary,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: colors.surfaceBorder.withAlpha(100),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _selectedGender == VoiceGender.female
                                ? Icons.face_3_rounded
                                : Icons.face_6_rounded,
                            color: colors.primary,
                            size: 18,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _selectedGender == VoiceGender.female
                                ? l10n.voiceGenderFemale
                                : l10n.voiceGenderMale,
                            style: typography.caption.bold.copyWith(
                              color: colors.textPrimary,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.swap_horiz_rounded,
                            color: colors.textSecondary,
                            size: 16,
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Drag indicator
                  Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colors.textSecondary.withAlpha(60),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),

                  // Close Button
                  IconButton(
                    icon: Icon(
                      Icons.close_rounded,
                      color: colors.textPrimary,
                    ),
                    onPressed: () {
                      unawaited(widget.ttsHandler.stop());
                      Navigator.of(context).pop();
                    },
                  ),
                ],
              ),

              const Spacer(),

              // 2. Central Interactive Voice Pulse Orb
              GestureDetector(
                onTap: () {
                  if (_state == DialogueState.listening) {
                    unawaited(_sttHandler.stopListening());
                  } else if (_state == DialogueState.speaking) {
                    unawaited(widget.ttsHandler.stop());
                    setState(() {
                      _state = DialogueState.idle;
                    });
                  } else {
                    unawaited(_startListening());
                  }
                },
                child: AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    final pulse = _pulseController.value;
                    final isListening = _state == DialogueState.listening;
                    final isSpeaking = _state == DialogueState.speaking;
                    final isThinking = _state == DialogueState.thinking;

                    final orbColor = isListening
                        ? colors.error
                        : isSpeaking
                            ? colors.syllabotAccent
                            : isThinking
                                ? colors.warning
                                : colors.primary;

                    return Stack(
                      alignment: Alignment.center,
                      children: [
                        // Outer Glow Ring
                        Container(
                          width: 140 + (pulse * 24),
                          height: 140 + (pulse * 24),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: orbColor.withAlpha(
                              (30 * (1 - pulse)).toInt(),
                            ),
                          ),
                        ),
                        // Middle Ring
                        Container(
                          width: 110 + (pulse * 12),
                          height: 110 + (pulse * 12),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: orbColor.withAlpha(
                              (60 * (1 - pulse)).toInt(),
                            ),
                          ),
                        ),
                        // Inner Orb
                        Container(
                          width: 88,
                          height: 88,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                orbColor.withAlpha(240),
                                orbColor,
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: orbColor.withAlpha(120),
                                blurRadius: 24,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: Icon(
                            isListening
                                ? Icons.mic_rounded
                                : isSpeaking
                                    ? Icons.volume_up_rounded
                                    : isThinking
                                        ? Icons.auto_awesome_rounded
                                        : Icons.mic_none_rounded,
                            color: Colors.white,
                            size: 38,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),

              const SizedBox(height: 24),

              // 3. Status Label
              Text(
                _state == DialogueState.listening
                    ? l10n.voiceDialogueListening
                    : _state == DialogueState.thinking
                        ? l10n.voiceDialogueThinking
                        : _state == DialogueState.speaking
                            ? l10n.voiceDialogueSpeaking
                            : l10n.voiceDialogueTapToSpeak,
                style: typography.title3.bold.copyWith(
                  color: colors.textPrimary,
                  fontSize: 18,
                ),
              ),

              const SizedBox(height: 12),

              // 4. Live Captions / Transcript Card
              if (_liveTranscript.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: colors.surfaceSecondary,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: colors.primary.withAlpha(60),
                    ),
                  ),
                  child: Text(
                    '"$_liveTranscript"',
                    textAlign: TextAlign.center,
                    style: typography.body.medium.copyWith(
                      color: colors.primary,
                      fontSize: 14,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),

              // 5. Spoken Response Markdown / Formula Viewer
              if (_latestResponse.isNotEmpty)
                Expanded(
                  flex: 3,
                  child: SingleChildScrollView(
                    child: ChatBubbleWidget(
                      message: ChatMessageEntity(
                        id: 'dialogue_response',
                        sessionId: 'dialogue_session',
                        text: _latestResponse,
                        sender: MessageSender.syllabot,
                        timestamp: DateTime.now(),
                      ),
                      ttsHandler: widget.ttsHandler,
                    ),
                  ),
                ),

              const Spacer(),

              // 6. Push to Talk Button
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: ShrinkableButton(
                  onTap: () {
                    if (_state == DialogueState.listening) {
                      unawaited(_sttHandler.stopListening());
                    } else if (_state == DialogueState.speaking) {
                      unawaited(widget.ttsHandler.stop());
                      setState(() {
                        _state = DialogueState.idle;
                      });
                    } else {
                      unawaited(_startListening());
                    }
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: _state == DialogueState.listening
                          ? colors.error
                          : colors.primary,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: (_state == DialogueState.listening
                                  ? colors.error
                                  : colors.primary)
                              .withAlpha(90),
                          blurRadius: 14,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _state == DialogueState.listening
                              ? Icons.stop_rounded
                              : Icons.mic_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _state == DialogueState.listening
                              ? l10n.voiceDialogueDoneSpeaking
                              : l10n.voiceDialogueTapToSpeak,
                          style: typography.body.bold.copyWith(
                            color: Colors.white,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
