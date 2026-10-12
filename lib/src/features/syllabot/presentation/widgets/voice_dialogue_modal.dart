import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/audio_earcon_service.dart';
import 'package:kortex/src/core/themes/app_motion.dart';
import 'package:kortex/src/di/locator.dart';
import 'package:kortex/src/features/syllabot/domain/entities/execution_engine_type.dart';
import 'package:kortex/src/features/syllabot/domain/entities/socratic_mode.dart';
import 'package:kortex/src/features/syllabot/presentation/widgets/speech_to_text_handler.dart';
import 'package:kortex/src/features/syllabot/presentation/widgets/text_to_speech_handler.dart';
import 'package:kortex/src/features/syllabot/presentation/widgets/voice_dialogue/dialogue_state.dart';
import 'package:kortex/src/features/syllabot/presentation/widgets/voice_dialogue/voice_dialogue_modal_body.dart';
import 'package:kortex/src/features/syllabot/presentation/widgets/voice_dialogue/voice_dialogue_modal_shell.dart';
import 'package:kortex/src/features/syllabot/presentation/widgets/voice_dialogue/voice_stream_speech_coordinator.dart';
import 'package:kortex/src/shared/widgets/app_adaptive_sheet.dart';

export 'package:kortex/src/features/syllabot/presentation/widgets/voice_dialogue/dialogue_state.dart';

/// Industry-standard interactive AI voice dialogue modal.
class VoiceDialogueModal extends StatefulWidget {
  const VoiceDialogueModal({
    required this.ttsHandler,
    this.onSendPrompt,
    this.onStreamPrompt,
    this.initialMode = SocraticMode.stepByStep,
    this.engineType = ExecutionEngineType.cloudRemote,
    this.isFullScreenOverlay = false,
    this.audioEarconService,
    super.key,
  }) : assert(
         onSendPrompt != null || onStreamPrompt != null,
         'Either onSendPrompt or onStreamPrompt must be provided',
       );

  final Future<String> Function(String prompt)? onSendPrompt;
  final Stream<String> Function(String prompt)? onStreamPrompt;
  final TextToSpeechHandler ttsHandler;
  final SocraticMode initialMode;
  final ExecutionEngineType engineType;
  final bool isFullScreenOverlay;
  final AudioEarconService? audioEarconService;

  static Future<void> show({
    required BuildContext context,
    required TextToSpeechHandler ttsHandler,
    Future<String> Function(String prompt)? onSendPrompt,
    Stream<String> Function(String prompt)? onStreamPrompt,
    SocraticMode initialMode = SocraticMode.stepByStep,
    ExecutionEngineType engineType = ExecutionEngineType.cloudRemote,
    AudioEarconService? audioEarconService,
  }) {
    final isDesktop = AppAdaptiveSheet.isDesktopOrWeb(context);
    if (isDesktop) {
      return showGeneralDialog<void>(
        context: context,
        barrierDismissible: true,
        barrierLabel: 'Dismiss Voice Dialogue',
        barrierColor: Colors.black.withValues(alpha: 0.75),
        transitionDuration: AppMotion.snappy,
        transitionBuilder: (context, anim1, anim2, child) {
          final curved = AppMotion.easeOutCubic.transform(anim1.value);
          return Transform.scale(
            scale: 0.95 + (0.05 * curved),
            child: Opacity(
              opacity: anim1.value.clamp(0.0, 1.0),
              child: child,
            ),
          );
        },
        pageBuilder: (dialogContext, animation, secondaryAnimation) {
          return Material(
            type: MaterialType.transparency,
            child: VoiceDialogueModal(
              onSendPrompt: onSendPrompt,
              onStreamPrompt: onStreamPrompt,
              ttsHandler: ttsHandler,
              initialMode: initialMode,
              engineType: engineType,
              isFullScreenOverlay: true,
              audioEarconService: audioEarconService,
            ),
          );
        },
      );
    }

    return AppAdaptiveSheet.showModal<void>(
      context: context,
      maxWidth: 620,
      builder: (context) => VoiceDialogueModal(
        onSendPrompt: onSendPrompt,
        onStreamPrompt: onStreamPrompt,
        ttsHandler: ttsHandler,
        initialMode: initialMode,
        engineType: engineType,
        audioEarconService: audioEarconService,
      ),
    );
  }

  @override
  State<VoiceDialogueModal> createState() => _VoiceDialogueModalState();
}

class _VoiceDialogueModalState extends State<VoiceDialogueModal>
    with SingleTickerProviderStateMixin {
  late final SpeechToTextHandler _sttHandler;
  late final AnimationController _ribbonAnimationController;
  late final AudioEarconService _earconService;

  /// High-performance decibel notifier avoiding full modal rebuilds during mic streaming.
  final ValueNotifier<double> _soundLevelNotifier = ValueNotifier<double>(0);

  DialogueState _state = DialogueState.idle;
  String _liveTranscript = '';
  String _accumulatedTranscript = '';
  String _latestResponse = '';
  late VoiceGender _selectedGender;
  bool _isMuted = false;
  bool _isTranscriptExpanded = false;
  bool _isProcessingPrompt = false;

  Timer? _silenceTimer;
  Timer? _restartListeningTimer;

  static const Duration _silenceThreshold = Duration(milliseconds: 1200);

  @override
  void initState() {
    super.initState();
    _selectedGender = widget.ttsHandler.voiceGender;

    _earconService = widget.audioEarconService ??
        (locator.isRegistered<AudioEarconService>()
            ? locator<AudioEarconService>()
            : AudioEarconServiceImpl());

    _ribbonAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );
    unawaited(_ribbonAnimationController.repeat());

    _sttHandler = SpeechToTextHandler(
      onResult: (text) {},
      onResultWithFinal: (text, {required isFinal}) {
        if (!mounted || _state != DialogueState.listening) return;
        final words = text.trim();
        if (words.isEmpty) return;

        final fullTranscript = _accumulatedTranscript.isNotEmpty
            ? '$_accumulatedTranscript $words'
            : words;

        setState(() {
          _liveTranscript = fullTranscript;
        });

        if (isFinal) {
          unawaited(_commitVoicePromptImmediately());
        } else {
          _resetSilenceTimer();
        }
      },
      onSoundLevelChange: (level) {
        if (!mounted || _state != DialogueState.listening) return;
        final normalized = ((level + 40.0) / 50.0).clamp(0.0, 1.0);
        if ((normalized - _soundLevelNotifier.value).abs() > 0.02) {
          _soundLevelNotifier.value = normalized;
        }
      },
      onListeningChanged: (listening) {
        if (!mounted) return;
        if (_state == DialogueState.listening && !listening) {
          final prompt = _liveTranscript.trim();
          if (prompt.isNotEmpty) {
            unawaited(_commitVoicePromptImmediately());
          } else {
            setState(() {
              _state = DialogueState.idle;
            });
            _soundLevelNotifier.value = 0;
          }
        }
      },
      onError: (err) {
        if (!mounted) return;
        unawaited(_earconService.playError());
        final errorMsg = 'Microphone error: $err';
        if (_state == DialogueState.listening) {
          setState(() {
            _latestResponse = errorMsg;
            _state = DialogueState.idle;
          });
          _soundLevelNotifier.value = 0;
          if (!_isMuted) {
            unawaited(widget.ttsHandler.speak(errorMsg));
          }
        }
      },
    );

    // Speak initial Syllabot greeting, then start conversational loop
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
    if (_state != DialogueState.listening) return;
    await _commitVoicePromptImmediately();
  }

  Future<void> _commitVoicePromptImmediately() async {
    _silenceTimer?.cancel();
    _silenceTimer = null;
    _restartListeningTimer?.cancel();
    _restartListeningTimer = null;
    if (_state != DialogueState.listening || _isProcessingPrompt) return;

    final prompt = _liveTranscript.trim();
    if (prompt.isNotEmpty) {
      setState(() {
        _state = DialogueState.thinking;
      });
      _soundLevelNotifier.value = 0;
      unawaited(_earconService.playProcessingCommit());
      await _sttHandler.stopListening();
      await _processVoicePrompt(prompt);
    } else {
      unawaited(_sttHandler.stopListening());
      if (mounted) {
        setState(() {
          _state = DialogueState.idle;
        });
        _soundLevelNotifier.value = 0;
      }
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

    if (!_isMuted) {
      await widget.ttsHandler.speak(greeting);
      await widget.ttsHandler.waitForQueueDrained();
    } else {
      await Future<void>.delayed(const Duration(milliseconds: 1000));
    }

    if (mounted &&
        (_state == DialogueState.speaking || _state == DialogueState.idle)) {
      await Future<void>.delayed(const Duration(milliseconds: 350));
      if (mounted &&
          (_state == DialogueState.speaking || _state == DialogueState.idle)) {
        await _startListening();
      }
    }
  }

  @override
  void dispose() {
    _silenceTimer?.cancel();
    _restartListeningTimer?.cancel();
    _ribbonAnimationController.dispose();
    _soundLevelNotifier.dispose();
    _sttHandler.dispose();
    super.dispose();
  }

  Future<void> _startListening() async {
    _silenceTimer?.cancel();
    _silenceTimer = null;
    _restartListeningTimer?.cancel();
    _restartListeningTimer = null;
    await widget.ttsHandler.stop();
    if (!mounted) return;

    setState(() {
      _state = DialogueState.listening;
      _liveTranscript = '';
      _accumulatedTranscript = '';
    });
    _soundLevelNotifier.value = 0;

    unawaited(_earconService.playListeningStart());
    await _sttHandler.startListening(
      pauseFor: const Duration(milliseconds: 1800),
    );
  }

  Future<void> _processVoicePrompt(String prompt) async {
    if (_isProcessingPrompt) return;
    _isProcessingPrompt = true;
    _silenceTimer?.cancel();
    _silenceTimer = null;

    if (!mounted) {
      _isProcessingPrompt = false;
      return;
    }

    setState(() {
      _state = DialogueState.thinking;
      _latestResponse = '';
    });
    _soundLevelNotifier.value = 0;

    if (!_isMuted) {
      unawaited(widget.ttsHandler.speak('Thinking...'));
    }

    try {
      if (widget.onStreamPrompt != null) {
        await VoiceStreamSpeechCoordinator.processStream(
          stream: widget.onStreamPrompt!(prompt),
          ttsHandler: widget.ttsHandler,
          isMuted: _isMuted,
          isCancelled: () => !mounted || _state == DialogueState.idle,
          onFirstSentenceSpoken: () {
            if (mounted) {
              setState(() {
                _state = DialogueState.speaking;
              });
              unawaited(_earconService.playSpeakingStart());
            }
          },
          onChunkReceived: (chunk) {
            if (mounted) {
              setState(() {
                _latestResponse = _latestResponse.isEmpty
                    ? chunk
                    : '$_latestResponse$chunk';
              });
            }
          },
        );

        if (mounted &&
            (_state == DialogueState.speaking ||
                _state == DialogueState.thinking)) {
          await Future<void>.delayed(const Duration(milliseconds: 350));
          if (mounted &&
              (_state == DialogueState.speaking ||
                  _state == DialogueState.thinking)) {
            await _startListening();
          }
        }
        return;
      }

      if (widget.onSendPrompt != null) {
        final response = await widget.onSendPrompt!(prompt).timeout(
          const Duration(seconds: 180),
        );
        if (!mounted) return;

        setState(() {
          _latestResponse = response;
          _state = DialogueState.speaking;
        });

        if (!_isMuted) {
          await widget.ttsHandler.speak(response);
          await widget.ttsHandler.waitForQueueDrained();
        } else {
          await Future<void>.delayed(const Duration(milliseconds: 1000));
        }

        if (mounted &&
            (_state == DialogueState.speaking ||
                _state == DialogueState.thinking)) {
          await Future<void>.delayed(const Duration(milliseconds: 350));
          if (mounted &&
              (_state == DialogueState.speaking ||
                  _state == DialogueState.thinking)) {
            await _startListening();
          }
        }
      }
    } on Object catch (e) {
      unawaited(_earconService.playError());
      final rawMsg = e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
      final errorText = rawMsg.isNotEmpty
          ? 'Sorry, an error occurred: $rawMsg'
          : 'Sorry, I ran into an error processing your question. Please try again.';

      if (mounted) {
        setState(() {
          _latestResponse = errorText;
          _state = DialogueState.idle;
        });
        _soundLevelNotifier.value = 0;

        if (!_isMuted) {
          await widget.ttsHandler.speak(errorText);
        }
      }
    } finally {
      _isProcessingPrompt = false;
    }
  }

  void _onInteractionTap() {
    unawaited(HapticFeedback.lightImpact());
    if (_state == DialogueState.listening) {
      if (_liveTranscript.trim().isNotEmpty) {
        unawaited(_commitVoicePromptImmediately());
      } else {
        _silenceTimer?.cancel();
        _silenceTimer = null;
        _restartListeningTimer?.cancel();
        _restartListeningTimer = null;
        setState(() {
          _state = DialogueState.idle;
        });
        _soundLevelNotifier.value = 0;
        unawaited(_sttHandler.stopListening());
      }
    } else if (_state == DialogueState.speaking ||
        _state == DialogueState.thinking) {
      _isProcessingPrompt = false;
      unawaited(widget.ttsHandler.stop());
      unawaited(_startListening());
    } else if (_state == DialogueState.idle) {
      _isProcessingPrompt = false;
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

  void _toggleMute() {
    unawaited(HapticFeedback.selectionClick());
    setState(() {
      _isMuted = !_isMuted;
    });
    if (_isMuted) {
      unawaited(widget.ttsHandler.stop());
    }
  }

  void _closeModal() {
    _silenceTimer?.cancel();
    _restartListeningTimer?.cancel();
    unawaited(widget.ttsHandler.stop());
    unawaited(_sttHandler.stopListening());
    if (mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDesktop =
        AppAdaptiveSheet.isDesktopOrWeb(context) || widget.isFullScreenOverlay;

    // Primary State Color Tone
    final stateColor = switch (_state) {
      DialogueState.listening => colors.primary,
      DialogueState.speaking => colors.syllabotAccent,
      DialogueState.thinking => colors.warning,
      DialogueState.idle => colors.primary.withValues(alpha: 0.8),
    };

    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.escape) {
            _closeModal();
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.space) {
            _onInteractionTap();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxHeight < 680;
          final isLandscape =
              constraints.maxWidth > constraints.maxHeight &&
              constraints.maxHeight < 520;

          return VoiceDialogueModalShell(
            isDesktop: isDesktop,
            constraints: constraints,
            stateColor: stateColor,
            onCloseModal: _closeModal,
            child: VoiceDialogueModalBody(
              engineType: widget.engineType,
              initialMode: widget.initialMode,
              selectedGender: _selectedGender,
              isDesktop: isDesktop,
              isLandscape: isLandscape,
              isCompact: isCompact,
              stateColor: stateColor,
              state: _state,
              soundLevelNotifier: _soundLevelNotifier,
              ribbonAnimationController: _ribbonAnimationController,
              liveTranscript: _liveTranscript,
              latestResponse: _latestResponse,
              ttsHandler: widget.ttsHandler,
              isTranscriptExpanded: _isTranscriptExpanded,
              isMuted: _isMuted,
              onToggleGender: _toggleGender,
              onCloseModal: _closeModal,
              onInteractionTap: _onInteractionTap,
              onToggleTranscriptExpanded: () {
                unawaited(HapticFeedback.lightImpact());
                setState(() {
                  _isTranscriptExpanded = !_isTranscriptExpanded;
                });
              },
              onToggleMute: _toggleMute,
            ),
          );
        },
      ),
    );
  }
}
