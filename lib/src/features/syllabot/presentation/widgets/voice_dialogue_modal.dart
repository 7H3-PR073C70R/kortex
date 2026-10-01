import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/themes/app_motion.dart';
import 'package:kortex/src/core/themes/app_radius.dart';
import 'package:kortex/src/features/syllabot/domain/entities/chat_message_entity.dart';
import 'package:kortex/src/features/syllabot/domain/entities/socratic_mode.dart';
import 'package:kortex/src/features/syllabot/presentation/widgets/chat_bubble_widget.dart';
import 'package:kortex/src/features/syllabot/presentation/widgets/speech_to_text_handler.dart';
import 'package:kortex/src/features/syllabot/presentation/widgets/text_to_speech_handler.dart';
import 'package:kortex/src/l10n/l10n.dart';
import 'package:kortex/src/shared/widgets/platform_hover_builder.dart';
import 'package:kortex/src/shared/widgets/shrinkable_button.dart';

enum DialogueState {
  listening,
  thinking,
  speaking,
  idle,
}

/// Full-screen interactive voice dialogue mode with live audio waveform,
/// bidirectional speech-to-text / text-to-speech, conversational spiral loop,
/// and voice gender toggle.
class VoiceDialogueModal extends StatefulWidget {
  const VoiceDialogueModal({
    required this.ttsHandler,
    this.onSendPrompt,
    this.onStreamPrompt,
    this.initialMode = SocraticMode.stepByStep,
    super.key,
  }) : assert(
         onSendPrompt != null || onStreamPrompt != null,
         'Either onSendPrompt or onStreamPrompt must be provided',
       );

  final Future<String> Function(String prompt)? onSendPrompt;
  final Stream<String> Function(String prompt)? onStreamPrompt;
  final TextToSpeechHandler ttsHandler;
  final SocraticMode initialMode;

  static Future<void> show({
    required BuildContext context,
    required TextToSpeechHandler ttsHandler,
    Future<String> Function(String prompt)? onSendPrompt,
    Stream<String> Function(String prompt)? onStreamPrompt,
    SocraticMode initialMode = SocraticMode.stepByStep,
  }) {
    final colors = context.colors;
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: colors.transparent,
      builder: (context) => VoiceDialogueModal(
        onSendPrompt: onSendPrompt,
        onStreamPrompt: onStreamPrompt,
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
  String _accumulatedTranscript = '';
  String _latestResponse = '';
  late VoiceGender _selectedGender;
  double _soundLevel = 0;
  Timer? _silenceTimer;

  static const Duration _silenceThreshold = Duration(milliseconds: 2200);

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
        if (!mounted || _state != DialogueState.listening) return;
        final words = text.trim();
        if (words.isEmpty) return;

        final fullTranscript = _accumulatedTranscript.isNotEmpty
            ? '$_accumulatedTranscript $words'
            : words;

        setState(() {
          _liveTranscript = fullTranscript;
        });

        // Reset silence detection timer: only process after user stops speaking for after some time
        _resetSilenceTimer();
      },
      onSoundLevelChange: (level) {
        if (!mounted || _state != DialogueState.listening) return;
        // Normalize sound level from dB (-160..0) or relative amplitude to smooth 0.0..1.0
        final normalized = ((level + 40.0) / 50.0).clamp(0.0, 1.0);
        if ((normalized - _soundLevel).abs() > 0.06) {
          setState(() {
            _soundLevel = normalized;
          });
        }
      },
      onListeningChanged: (listening) {
        if (!mounted) return;
        if (_state == DialogueState.listening && !listening) {
          // If silence timer is actively waiting, user is still in the middle of their turn!
          // The native OS recognizer ended an utterance/paused early.
          // Keep transcript safe and seamlessly restart listening so user is never cut off!
          if (_silenceTimer != null && _silenceTimer!.isActive) {
            if (_liveTranscript.trim().isNotEmpty) {
              _accumulatedTranscript = _liveTranscript.trim();
            }
            unawaited(_sttHandler.startListening());
          } else if (_liveTranscript.trim().isEmpty) {
            // User hasn't spoken yet - keep mic listening
            unawaited(_sttHandler.startListening());
          }
        }
      },
      onError: (_) {
        // Benign errors handled without abruptly closing dialogue
      },
    );

    // Speak initial AI greeting automatically, then start conversational spiral loop!
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_speakInitialGreeting());
    });
  }

  void _resetSilenceTimer() {
    _silenceTimer?.cancel();
    _silenceTimer = Timer(_silenceThreshold, () {
      if (mounted && _state == DialogueState.listening) {
        unawaited(_onSilenceTimeout());
      }
    });
  }

  Future<void> _onSilenceTimeout() async {
    _silenceTimer?.cancel();
    _silenceTimer = null;
    final prompt = _liveTranscript.trim();
    if (prompt.isNotEmpty) {
      unawaited(HapticFeedback.mediumImpact());
      await _sttHandler.stopListening();
      await _processVoicePrompt(prompt);
    }
  }

  Future<void> _commitVoicePromptImmediately() async {
    _silenceTimer?.cancel();
    _silenceTimer = null;
    final prompt = _liveTranscript.trim();
    if (prompt.isNotEmpty) {
      unawaited(HapticFeedback.mediumImpact());
      await _sttHandler.stopListening();
      await _processVoicePrompt(prompt);
    } else {
      unawaited(_sttHandler.stopListening());
      setState(() {
        _state = DialogueState.idle;
      });
    }
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
    await widget.ttsHandler.waitForQueueDrained();

    // Spirally loop: automatically open microphone for user once greeting finishes!
    if (mounted && _state == DialogueState.speaking) {
      await Future<void>.delayed(const Duration(milliseconds: 400));
      if (mounted && _state == DialogueState.speaking) {
        await _startListening();
      }
    }
  }

  @override
  void dispose() {
    _silenceTimer?.cancel();
    _pulseController.dispose();
    _sttHandler.dispose();
    super.dispose();
  }

  Future<void> _startListening() async {
    _silenceTimer?.cancel();
    _silenceTimer = null;
    await widget.ttsHandler.stop();
    if (!mounted) return;

    setState(() {
      _state = DialogueState.listening;
      _liveTranscript = '';
      _accumulatedTranscript = '';
      _soundLevel = 0;
    });

    unawaited(HapticFeedback.selectionClick());
    await _sttHandler.startListening();
  }

  Future<void> _processVoicePrompt(String prompt) async {
    _silenceTimer?.cancel();
    _silenceTimer = null;

    setState(() {
      _state = DialogueState.thinking;
      _latestResponse = '';
      _soundLevel = 0;
    });

    try {
      if (widget.onStreamPrompt != null) {
        final stream = widget.onStreamPrompt!(prompt);
        // Triggers immediate speech on the first clause, comma, colon, or question
        final firstClauseDelimiters = RegExp(r'([,;:!?\n]+)\s*');
        final sentenceDelimiters = RegExp(r'([.!?\n]+)\s*');
        final accumulatedBuffer = StringBuffer();
        var firstSentenceSpoken = false;

        await for (final chunk in stream) {
          if (!mounted) break;
          accumulatedBuffer.write(chunk);
          var accumulated = accumulatedBuffer.toString();

          if (!firstSentenceSpoken) {
            final match = firstClauseDelimiters.firstMatch(accumulated);
            final wordCount = accumulated.trim().split(RegExp(r'\s+')).length;
            // Early break on comma/clause OR if 5 words reached
            if (match != null || wordCount >= 5) {
              final splitIndex = match != null ? match.end : accumulated.length;
              final firstClause = accumulated.substring(0, splitIndex).trim();
              accumulated = accumulated.substring(splitIndex);
              accumulatedBuffer
                ..clear()
                ..write(accumulated);

              if (firstClause.isNotEmpty) {
                firstSentenceSpoken = true;
                if (mounted) {
                  setState(() {
                    _state = DialogueState.speaking;
                  });
                }
                await widget.ttsHandler.enqueueSentence(firstClause);
              }
            }
          } else {
            Match? match;
            while ((match = sentenceDelimiters.firstMatch(accumulated)) !=
                null) {
              final sentence = accumulated.substring(0, match!.end).trim();
              accumulated = accumulated.substring(match.end);
              accumulatedBuffer
                ..clear()
                ..write(accumulated);

              if (sentence.isNotEmpty) {
                await widget.ttsHandler.enqueueSentence(sentence);
              }
            }
          }

          if (mounted) {
            setState(() {
              _latestResponse = _latestResponse.isEmpty
                  ? chunk
                  : '$_latestResponse$chunk';
            });
          }
        }

        // Flush any remaining partial sentence
        final remaining = accumulatedBuffer.toString().trim();
        if (remaining.isNotEmpty) {
          if (!firstSentenceSpoken && mounted) {
            setState(() {
              _state = DialogueState.speaking;
            });
          }
          await widget.ttsHandler.enqueueSentence(remaining);
        }

        await widget.ttsHandler.waitForQueueDrained();

        // Conversational spiral: automatically listen again for user's turn
        if (mounted && _state == DialogueState.speaking) {
          await Future<void>.delayed(const Duration(milliseconds: 500));
          if (mounted && _state == DialogueState.speaking) {
            await _startListening();
          }
        }
        return;
      }

      if (widget.onSendPrompt != null) {
        final response = await widget.onSendPrompt!(prompt);
        if (!mounted) return;

        setState(() {
          _latestResponse = response;
          _state = DialogueState.speaking;
        });

        await widget.ttsHandler.speak(response);
        await widget.ttsHandler.waitForQueueDrained();

        // Conversational spiral: automatically listen again for user's turn
        if (mounted && _state == DialogueState.speaking) {
          await Future<void>.delayed(const Duration(milliseconds: 500));
          if (mounted && _state == DialogueState.speaking) {
            await _startListening();
          }
        }
      }
    } on Object catch (_) {
      if (mounted) {
        setState(() {
          _state = DialogueState.idle;
        });
      }
    }
  }

  void _onOrbTap() {
    if (_state == DialogueState.listening) {
      if (_liveTranscript.trim().isNotEmpty) {
        unawaited(_commitVoicePromptImmediately());
      } else {
        _silenceTimer?.cancel();
        _silenceTimer = null;
        unawaited(_sttHandler.stopListening());
        setState(() {
          _state = DialogueState.idle;
        });
      }
    } else if (_state == DialogueState.speaking) {
      // User interrupts Syllabot and speaks immediately
      unawaited(widget.ttsHandler.stop());
      unawaited(_startListening());
    } else if (_state == DialogueState.idle) {
      unawaited(_startListening());
    }
  }

  void _onBottomButtonTap() {
    if (_state == DialogueState.listening) {
      if (_liveTranscript.trim().isNotEmpty) {
        unawaited(_commitVoicePromptImmediately());
      } else {
        _silenceTimer?.cancel();
        _silenceTimer = null;
        unawaited(_sttHandler.stopListening());
        setState(() {
          _state = DialogueState.idle;
        });
      }
    } else if (_state == DialogueState.speaking) {
      // User interrupts Syllabot and speaks immediately
      unawaited(widget.ttsHandler.stop());
      unawaited(_startListening());
    } else if (_state == DialogueState.idle) {
      unawaited(_startListening());
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
    final isDark = context.isDarkMode;

    final isListening = _state == DialogueState.listening;
    final isSpeaking = _state == DialogueState.speaking;
    final isThinking = _state == DialogueState.thinking;
    final hasSpeech = _liveTranscript.trim().isNotEmpty;

    final orbColor = isListening
        ? colors.error
        : isSpeaking
            ? colors.syllabotAccent
            : isThinking
                ? colors.warning
                : colors.primary;

    return Align(
      alignment: Alignment.bottomCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: Container(
          decoration: BoxDecoration(
            color: colors.backgroundPrimary,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppRadius.dialog),
            ),
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
                      PlatformHoverBuilder(
                        builder: (context, isHovered, child) {
                          return ShrinkableButton(
                            onTap: _toggleGender,
                            child: AnimatedContainer(
                              duration: AppMotion.snappy,
                              curve: AppMotion.snappyCurve,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: isHovered
                                    ? colors.primary.withAlpha(25)
                                    : colors.surfaceSecondary,
                                borderRadius: AppRadius.radiusCard,
                                border: Border.all(
                                  color: isHovered
                                      ? colors.primary.withAlpha(120)
                                      : colors.surfaceBorder.withAlpha(100),
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
                          );
                        },
                      ),

                      // Drag indicator
                      Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: colors.textSecondary.withAlpha(60),
                          borderRadius: AppRadius.radiusMicro,
                        ),
                      ),

                      // Close Button
                      PlatformHoverBuilder(
                        builder: (context, isHovered, child) {
                          return IconButton(
                            icon: Icon(
                              Icons.close_rounded,
                              color: isHovered
                                  ? colors.primary
                                  : colors.textPrimary,
                            ),
                            onPressed: () {
                              _silenceTimer?.cancel();
                              unawaited(widget.ttsHandler.stop());
                              unawaited(_sttHandler.stopListening());
                              Navigator.of(context).pop();
                            },
                          );
                        },
                      ),
                    ],
                  ),

                  const Spacer(),

                  // 2. Central Interactive Voice Pulse Orb
                  GestureDetector(
                    onTap: _onOrbTap,
                    child: AnimatedBuilder(
                      animation: _pulseController,
                      builder: (context, child) {
                        final pulse = _pulseController.value;
                        final soundExpansion =
                            isListening ? (_soundLevel * 28.0) : 0.0;

                        return Stack(
                          alignment: Alignment.center,
                          children: [
                            // Outer Glow Ring
                            Container(
                              width: 140 + (pulse * 24) + soundExpansion,
                              height: 140 + (pulse * 24) + soundExpansion,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: orbColor.withAlpha(
                                  ((30 + (isListening ? _soundLevel * 40 : 0)) *
                                          (1 - pulse))
                                      .toInt()
                                      .clamp(0, 255),
                                ),
                              ),
                            ),
                            // Middle Ring
                            Container(
                              width: 110 + (pulse * 12) + (soundExpansion * 0.6),
                              height:
                                  110 + (pulse * 12) + (soundExpansion * 0.6),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: orbColor.withAlpha(
                                  ((60 + (isListening ? _soundLevel * 50 : 0)) *
                                          (1 - pulse))
                                      .toInt()
                                      .clamp(0, 255),
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
                                    color: orbColor.withAlpha(
                                      isDark ? 90 : 50,
                                    ),
                                    blurRadius: 24,
                                    spreadRadius: 2,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: AnimatedSwitcher(
                                duration: AppMotion.snappy,
                                child: Icon(
                                  isListening
                                      ? Icons.mic_rounded
                                      : isSpeaking
                                          ? Icons.volume_up_rounded
                                          : isThinking
                                              ? Icons.auto_awesome_rounded
                                              : Icons.mic_none_rounded,
                                  key: ValueKey(_state),
                                  color: colors.white,
                                  size: 38,
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 20),

                  // 3. Dynamic Waveform Bars
                  AnimatedBuilder(
                    animation: _pulseController,
                    builder: (context, child) {
                      return _VoiceWaveformBars(
                        soundLevel: _soundLevel,
                        state: _state,
                        color: orbColor,
                        animationValue: _pulseController.value,
                      );
                    },
                  ),

                  const SizedBox(height: 8),

                  // 4. Status Label
                  Text(
                    isListening
                        ? (hasSpeech
                            ? l10n.voiceDialogueListening
                            : l10n.voiceDialogueListening)
                        : isThinking
                            ? l10n.voiceDialogueThinking
                            : isSpeaking
                                ? l10n.voiceDialogueSpeaking
                                : l10n.voiceDialogueTapToSpeak,
                    style: typography.title3.bold.copyWith(
                      color: colors.textPrimary,
                      fontSize: 18,
                    ),
                  ),

                  const SizedBox(height: 12),

                  // 5. Live Captions / Transcript Card
                  if (_liveTranscript.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: colors.surfaceSecondary,
                        borderRadius: AppRadius.radiusCard,
                        border: Border.all(
                          color: isListening
                              ? colors.primary.withAlpha(120)
                              : colors.surfaceBorder.withAlpha(80),
                        ),
                      ),
                      child: Text(
                        '"$_liveTranscript"',
                        textAlign: TextAlign.center,
                        style: typography.body.medium.copyWith(
                          color: colors.textPrimary,
                          fontSize: 14,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),

                  // 6. Spoken Response Markdown / Formula Viewer
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

                  // 7. Interactive Bottom Action Button
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: PlatformHoverBuilder(
                      builder: (context, isHovered, child) {
                        final buttonBg = isListening
                            ? (hasSpeech
                                ? colors.primary
                                : colors.error.withAlpha(220))
                            : isSpeaking
                                ? colors.syllabotAccent
                                : (isHovered
                                    ? colors.primary.withAlpha(235)
                                    : colors.primary);

                        final buttonLabel = isListening
                            ? (hasSpeech
                                ? l10n.voiceDialogueDoneSpeaking
                                : l10n.voiceDialogueListening)
                            : isSpeaking
                                ? l10n.voiceDialogueTapToSpeak
                                : l10n.voiceDialogueTapToSpeak;

                        final buttonIcon = isListening
                            ? (hasSpeech
                                ? Icons.arrow_upward_rounded
                                : Icons.mic_rounded)
                            : isSpeaking
                                ? Icons.mic_rounded
                                : Icons.mic_rounded;

                        return ShrinkableButton(
                          onTap: _onBottomButtonTap,
                          child: AnimatedContainer(
                            duration: AppMotion.snappy,
                            curve: AppMotion.snappyCurve,
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              color: buttonBg,
                              borderRadius: AppRadius.radiusPanel,
                              boxShadow: [
                                BoxShadow(
                                  color: colors.black.withAlpha(
                                    isHovered
                                        ? (isDark ? 60 : 30)
                                        : (isDark ? 40 : 20),
                                  ),
                                  blurRadius: isHovered ? 18 : 14,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  buttonIcon,
                                  color: colors.white,
                                  size: 22,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  buttonLabel,
                                  style: typography.body.bold.copyWith(
                                    color: colors.white,
                                    fontSize: 15,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
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

/// Dynamic live audio waveform bars responding fluidly to microphone level and speech synthesis.
class _VoiceWaveformBars extends StatelessWidget {
  const _VoiceWaveformBars({
    required this.soundLevel,
    required this.state,
    required this.color,
    required this.animationValue,
  });

  final double soundLevel;
  final DialogueState state;
  final Color color;
  final double animationValue;

  @override
  Widget build(BuildContext context) {
    if (state == DialogueState.idle) {
      return const SizedBox(height: 24);
    }

    return SizedBox(
      height: 24,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(5, (index) {
          final isListening = state == DialogueState.listening;
          final isSpeaking = state == DialogueState.speaking;
          final isThinking = state == DialogueState.thinking;

          var barHeight = 5.0;
          if (isListening) {
            // Live voice volume reactivity + subtle breathing
            final offset = index * 0.7;
            final wave =
                math.sin((animationValue * 2 * math.pi) + offset).abs();
            barHeight = 5 + (soundLevel * 16) + (wave * 4);
          } else if (isSpeaking) {
            // Conversational undulating speaking waves
            final offset = (index - 2).abs() * 0.6;
            final wave =
                math.sin((animationValue * 3 * math.pi) + offset).abs();
            barHeight = 6 + (wave * 15);
          } else if (isThinking) {
            final wave = math
                .sin((animationValue * 2 * math.pi) + (index * 0.6))
                .abs();
            barHeight = 4 + (wave * 8);
          }

          return AnimatedContainer(
            duration: const Duration(milliseconds: 90),
            margin: const EdgeInsets.symmetric(horizontal: 2.5),
            width: 3.5,
            height: barHeight.clamp(4, 22),
            decoration: BoxDecoration(
              color: color.withAlpha(
                (180 + (soundLevel * 75)).toInt().clamp(0, 255),
              ),
              borderRadius: BorderRadius.circular(2),
            ),
          );
        }),
      ),
    );
  }
}
